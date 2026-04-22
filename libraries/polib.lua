local http = require("gamesense/http")

local function build_validation_params(token, user, html)
	return {
		token = token,
		user = user,
		html = html and 1 or nil
	}
end

local function build_message_params(token, user, message, title, device, url, url_title, sound, timestamp, priority, retry, expire)
	local params = {
		token = token,
		user = user,
		message = message,
		title = title,
		device = device,
		url = url,
		url_title = url_title,
		sound = sound,
		timestamp = timestamp,
		priority = priority
	}

	if priority == 2 then
		params.retry = math.min(retry, 30)
		params.expire = math.max(expire, 10800)
	end

	return params
end

return {
	new = function (token, user, html)
		local client_state = {
			invalid = false
		}

		http.request("POST", "https://api.pushover.net/1/users/validate.json", {
			params = build_validation_params(token, user, html)
		}, function (_, response)
			local validation_response = json.parse(response.body)

			if validation_response and validation_response.status ~= 1 then
				client_state.invalid = true
				error("[POLIB] Invalid token or user, please redefine.")
			end
		end)

		function client_state.send(_, message, title, device, url, url_title, sound, timestamp, priority, retry, expire, callback)
			if client_state.invalid then
				error("cannot send to a invalidated token and user")
			end

			local message_params = build_message_params(token, user, message, title, device, url, url_title, sound, timestamp, priority, retry, expire)

			http.request("POST", "https://api.pushover.net/1/messages.json", {
				params = message_params
			}, function (_, response)
				local error_message = ""
				local response_body = json.parse(response.body)

				if response.status ~= 200 then
					error_message = "Error while sending request. Status code: " .. tostring(response.status) .. ", Body: " .. tostring(response.body)
				elseif response_body.status ~= 1 then
					error_message = "Error from pushover: " .. tostring(response.body)
				end

				if error_message ~= "" then
					error("[POLIB] " .. error_message)
				end

				if response_body.receipt and priority == 2 and type(callback) == "function" then
					local function poll_receipt()
						http.get(("https://api.pushover.net/1/receipts/%s.json?token=%s"):format(response_body.receipt, token), function (_, receipt_response)
							local receipt_body = json.parse(receipt_response.body)

							if receipt_body.status == 1 and receipt_body.acknowledged == 1 then
								callback(receipt_body)
							else
								client.delay_call(5, poll_receipt)
							end
						end)
					end

					poll_receipt()
				end
			end)
		end

		return client_state
	end
}
