#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"

#include <cstdint>
#include <cstdlib>
#include <cstdio>
#include <fstream>
#include <memory>
#include <string>

#if defined(__APPLE__)
#define PSYCH_DISCORD_AUTH 1
#else
#define PSYCH_DISCORD_AUTH 0
#endif

namespace
{
	enum PsychDiscordStatus
	{
		PSYCH_DISCORD_OFFLINE = 0,
		PSYCH_DISCORD_CONNECTING = 1,
		PSYCH_DISCORD_READY = 2,
		PSYCH_DISCORD_ERROR = 3,
		PSYCH_DISCORD_NEEDS_LOGIN = 4
	};

	struct PsychPresence
	{
		std::string details;
		std::string state;
		std::string largeImage;
		std::string largeText;
		std::string smallImage;
		uint64_t start = 0;
		uint64_t end = 0;
		bool active = false;
	};

	std::shared_ptr<discordpp::Client> client;
	uint64_t applicationId = 0;
	std::string tokenPath;
	PsychPresence presence;
	int status = PSYCH_DISCORD_OFFLINE;
	bool authorizing = false;

	std::string readToken()
	{
		std::ifstream input(tokenPath);
		std::string token;
		if (input.good()) std::getline(input, token);
		return token;
	}

	void writeToken(const std::string &token)
	{
		if (tokenPath.empty()) return;
		if (token.empty())
		{
			std::remove(tokenPath.c_str());
			return;
		}
		std::ofstream output(tokenPath, std::ios::trunc);
		output << token;
	}

	discordpp::Activity buildActivity()
	{
		discordpp::Activity activity;
		activity.SetType(discordpp::ActivityTypes::Playing);
		if (!presence.details.empty()) activity.SetDetails(presence.details);
		if (!presence.state.empty()) activity.SetState(presence.state);

		if (presence.start > 0 || presence.end > 0)
		{
			discordpp::ActivityTimestamps timestamps;
			if (presence.start > 0) timestamps.SetStart(presence.start);
			if (presence.end > 0) timestamps.SetEnd(presence.end);
			activity.SetTimestamps(timestamps);
		}

		if (!presence.largeImage.empty() || !presence.smallImage.empty())
		{
			discordpp::ActivityAssets assets;
			if (!presence.largeImage.empty()) assets.SetLargeImage(presence.largeImage);
			if (!presence.largeText.empty()) assets.SetLargeText(presence.largeText);
			if (!presence.smallImage.empty()) assets.SetSmallImage(presence.smallImage);
			activity.SetAssets(assets);
		}
		return activity;
	}

	void pushPresence()
	{
		if (!client || !presence.active) return;
		#if PSYCH_DISCORD_AUTH
		if (status != PSYCH_DISCORD_READY) return;
		#endif
		client->UpdateRichPresence(buildActivity(), [](auto result) {
			#if !PSYCH_DISCORD_AUTH
			status = result.Successful() ? PSYCH_DISCORD_READY : PSYCH_DISCORD_ERROR;
			#endif
		});
	}

	#if PSYCH_DISCORD_AUTH
	template <typename Result, typename TokenType>
	void applyToken(Result result, const std::string &accessToken, const std::string &refreshToken, TokenType tokenType)
	{
		authorizing = false;
		if (!client) return;
		if (!result.Successful() || accessToken.empty())
		{
			writeToken("");
			status = PSYCH_DISCORD_NEEDS_LOGIN;
			return;
		}

		writeToken(refreshToken);
		client->UpdateToken(tokenType, accessToken, [](auto updateResult) {
			if (!client) return;
			if (updateResult.Successful())
			{
				status = PSYCH_DISCORD_CONNECTING;
				client->Connect();
			}
			else status = PSYCH_DISCORD_ERROR;
		});
	}

	auto tokenCallback()
	{
		return [](auto result, auto accessToken, auto refreshToken, auto tokenType, auto expiresIn, auto scopes) {
			applyToken(result, accessToken, refreshToken, tokenType);
		};
	}
	#endif
}

extern "C" void psych_discord_init(const char *appId, const char *savePath)
{
	if (client) return;

	applicationId = std::strtoull(appId ? appId : "0", nullptr, 10);
	tokenPath = savePath ? savePath : "";
	client = std::make_shared<discordpp::Client>();
	client->SetApplicationId(applicationId);

	#if PSYCH_DISCORD_AUTH
	client->SetStatusChangedCallback([](auto clientStatus, auto error, auto errorDetail) {
		if (clientStatus == discordpp::Client::Status::Ready)
		{
			status = PSYCH_DISCORD_READY;
			pushPresence();
		}
		else if (clientStatus == discordpp::Client::Status::Disconnected && status == PSYCH_DISCORD_READY)
			status = PSYCH_DISCORD_OFFLINE;
	});

	std::string refreshToken = readToken();
	if (refreshToken.empty())
	{
		status = PSYCH_DISCORD_NEEDS_LOGIN;
		return;
	}

	status = PSYCH_DISCORD_CONNECTING;
	authorizing = true;
	client->RefreshToken(applicationId, refreshToken, tokenCallback());
	#else
	status = PSYCH_DISCORD_CONNECTING;
	pushPresence();
	#endif
}

extern "C" void psych_discord_login(void)
{
	#if PSYCH_DISCORD_AUTH
	if (!client || authorizing || status == PSYCH_DISCORD_READY) return;

	authorizing = true;
	status = PSYCH_DISCORD_CONNECTING;

	auto verifier = client->CreateAuthorizationCodeVerifier();
	std::string verifierText = verifier.Verifier();

	discordpp::AuthorizationArgs args;
	args.SetClientId(applicationId);
	args.SetScopes(discordpp::Client::GetDefaultPresenceScopes());
	args.SetCodeChallenge(verifier.Challenge());

	client->Authorize(args, [verifierText](auto result, auto code, auto redirectUri) {
		if (!client) return;
		if (!result.Successful())
		{
			authorizing = false;
			status = PSYCH_DISCORD_NEEDS_LOGIN;
			return;
		}
		client->GetToken(applicationId, code, verifierText, redirectUri, tokenCallback());
	});
	#endif
}

extern "C" void psych_discord_logout(void)
{
	writeToken("");
	if (client && status == PSYCH_DISCORD_READY)
	{
		client->ClearRichPresence();
		#if PSYCH_DISCORD_AUTH
		client->Disconnect();
		status = PSYCH_DISCORD_NEEDS_LOGIN;
		#endif
	}
}

extern "C" void psych_discord_update(const char *details, const char *state, const char *largeImage, const char *largeText, const char *smallImage, double start, double end)
{
	presence.details = details ? details : "";
	presence.state = state ? state : "";
	presence.largeImage = largeImage ? largeImage : "";
	presence.largeText = largeText ? largeText : "";
	presence.smallImage = smallImage ? smallImage : "";
	presence.start = start > 0 ? (uint64_t)start : 0;
	presence.end = end > 0 ? (uint64_t)end : 0;
	presence.active = true;
	pushPresence();
}

extern "C" void psych_discord_clear(void)
{
	presence.active = false;
	if (client && status == PSYCH_DISCORD_READY) client->ClearRichPresence();
}

extern "C" int psych_discord_status(void)
{
	return status;
}

extern "C" void psych_discord_run_callbacks(void)
{
	if (client) discordpp::RunCallbacks();
}

extern "C" void psych_discord_shutdown(void)
{
	if (!client) return;
	if (status == PSYCH_DISCORD_READY) client->ClearRichPresence();
	#if PSYCH_DISCORD_AUTH
	client->Disconnect();
	#endif
	discordpp::RunCallbacks();
	client.reset();
	status = PSYCH_DISCORD_OFFLINE;
	authorizing = false;
}
