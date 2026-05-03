import http
import encoding.base64

import .params

interface Authentication:
  /**
  Applies the authentication to the $query-params and $header-params.
  */
  apply-to-params --query-params/List --header-params/http.Headers

class ApiKeyAuth implements Authentication:
  location/string
  param-name/string

  api-key-prefix/string
  api-key/string

  constructor
      --.location
      --.param-name
      --.api-key-prefix=""
      --.api-key="":

  apply-to-params --query-params/List --header-params/http.Headers:
    param-value := api-key-prefix == ""
        ? api-key
        : "$api-key-prefix $api-key"

    if param-value == "": return

    if location == "query":
      query-params.add (QueryParam param-name param-value)
    else if location == "header":
      header-params.add param-name param-value
    else if location == "cookie":
      assig := "$param-name=$param-value"
      existing-entries := header-params.get "Cookie"
      if not existing-entries or existing-entries.is-empty:
        header-params.set "Cookie" assig
      else:
        // Take the first (and hopefully only one) cookie and update it.
        existing := existing-entries.first
        updated := "$existing; $assig"
        header-params.set "Cookie" updated
        // Add the rest of the entries in case there were more.
        for i := 1; i < existing-entries.size; i++:
          header-params.add "Cookie" existing-entries[i]

class HttpBasicAuth implements Authentication:
  username/string
  password/string

  constructor --.username --.password:

  apply-to-params --query-params/List --header-params/http.Headers:
    if username == "" or password == "": return

    credentials := "$username:$password"
    header-params.add "Authorization" "Basic $(base64.encode credentials)"

abstract class HttpBearerAuth implements Authentication:
  abstract get-access-token_ -> string
  access-token_/string? := null

  constructor.token access-token/string:
    return HttpBearerAuthToken_ access-token

  constructor.callback callback/Lambda:
    return HttpBearerAuthCallback_ callback

  constructor.from-sub_:

  apply-to-params --query-params/List --header-params/http.Headers:
    if not access-token_: access-token_ = get-access-token_
    if access-token_ == "": return

    header-params.add "Authorization" "Bearer $access-token_"

class HttpBearerAuthToken_ extends HttpBearerAuth:
  access-token/string

  constructor .access-token:
    super.from-sub_

  get-access-token_ -> string:
    return access-token

class HttpBearerAuthCallback_ extends HttpBearerAuth:
  callback_/Lambda

  constructor .callback_:
    super.from-sub_

  get-access-token_ -> string:
    return callback_.call


class OAuth implements Authentication:
  access-token/string

  constructor .access-token:

  apply-to-params --query-params/List --header-params/http.Headers:
    if access-token == "": return

    header-params.add "Authorization" "Bearer $access-token"
