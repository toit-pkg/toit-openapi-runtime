import http
import io
import net
import http show Headers
import encoding.url as url-encoding

import .auth
import .params

export Headers

// https://github.com/OpenAPITools/openapi-generator/blob/master/samples/openapi3/client/petstore/dart2/petstore_client_lib/lib/api_client.dart

class ApiClient:
  base-path/string
  authentication/Authentication?

  client_/http.Client? := ?
  default-header-map_/Map ::= {:}

  constructor network/net.Client
      --.base-path
      --.authentication=null:
    client_ = http.Client network

  close:
    if client_:
      client_.close
      client_ = null

  add-default-header key/string value/string:
    default-header-map_[key] = value

  /**
  Invokes the API endpoint at $path.

  When $authentication is given it takes precedence over the client-level
    authentication passed to the constructor.
  */
  invoke-api -> http.Response
      --path/string
      --method/string
      --query-params/List  // of QueryParam
      --body/io.Data?=null
      --header-params/Headers
      --form-params/Map  // of string to string
      --content-type/string?
      --authentication/Authentication?=null
  :
    if content-type == "application/x-www-form-urlencoded":
      if body: throw "body and form-params cannot be used together"
      body = serialize-form_ form-params

    effective-authentication := authentication or this.authentication
    if effective-authentication:
      effective-authentication.apply-to-params
          --query-params=query-params
          --header-params=header-params

    default-header-map_.do: | key value |
      header-params.add key value

    if content-type:
      header-params.set "Content-Type" content-type

    url-encoded-query-params := query-params.map: | param/QueryParam |
      param.url-encode
    query-string := url-encoded-query-params.is-empty
        ? ""
        : "?$(url-encoded-query-params.join "&")"
    uri := "$base-path$path$query-string"

    request := client_.new-request method
        --uri=uri
        --headers=header-params
    if body and body is not ByteArray:
      body = ByteArray.from body
    if body:
      request.body = io.Reader (body as ByteArray)

    return request.send

  static serialize-form_ map/Map -> ByteArray:
    buffer := io.Buffer
    first := true
    map.do: | key value |
      if key is not string: throw "WRONG_OBJECT_TYPE"
      if value is not ByteArray:
        value = value.stringify
        if value is not string: throw "WRONG_OBJECT_TYPE"
      if first:
        first = false
      else:
        buffer.write "&"
      buffer.write
        url-encoding.encode key
      buffer.write "="
      buffer.write
        url-encoding.encode value
    return buffer.bytes
