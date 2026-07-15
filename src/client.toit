import http
import io
import net
import http show Headers
import encoding.url as url-encoding

import .auth
import .params

export Headers

// https://github.com/OpenAPITools/openapi-generator/blob/master/samples/openapi3/client/petstore/dart2/petstore_client_lib/lib/api_client.dart

/**
Base class for the `Api` class of generated clients.

Holds the underlying $ApiClient and the functionality that is identical
  across all generated clients; the generated subclass adds the
  spec-specific constructors and per-tag accessors.
*/
class ApiBase:
  /** The underlying client. Null after $close. */
  api-client/ApiClient? := ?

  constructor .api-client:

  /**
  Registers $authentication for the security scheme named $name.

  See $ApiClient.put-authentication.
  */
  put-authentication name/string authentication/Authentication -> none:
    api-client.put-authentication name authentication

  /** Closes the underlying $ApiClient. */
  close -> none:
    if not api-client: return
    api-client.close
    api-client = null

/**
Resolves $security against $authentications, a map from security-scheme
  name to $Authentication.

$security is a list of alternatives, of which one must be satisfied. Each
  alternative is a list of scheme names that must all be configured for
  the alternative to be satisfied.

Returns the authentications of the first satisfied alternative.
Returns the empty list if no alternative is satisfied but one of them is
  empty (authentication is optional).
Throws "AUTHENTICATION_MISSING" if no alternative is satisfied.
*/
resolve-security authentications/Map security/List -> List:
  optional := false
  security.do: | alternative/List |
    if alternative.is-empty:
      optional = true
      continue.do
    found := []
    alternative.do: | name/string |
      auth := authentications.get name
      if auth: found.add auth
    if found.size == alternative.size: return found
  if optional: return []
  throw "AUTHENTICATION_MISSING"

class ApiClient:
  base-path/string
  authentication/Authentication?
  authentications_/Map ::= {:}  // From security-scheme name to Authentication.

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
  Registers $authentication for the security scheme named $name.

  Generated operations resolve their security requirements against the
    registered schemes; see $invoke-api's `--security`.
  */
  put-authentication name/string authentication/Authentication -> none:
    authentications_[name] = authentication

  /**
  Invokes the API endpoint at $path.

  Authentication is chosen with the following precedence:
  - $authentication, when given, is applied as-is.
  - Otherwise $security, when given, is resolved against the schemes
    registered with $put-authentication; see $resolve-security.
  - Otherwise the client-level authentication passed to the constructor
    is applied, if any.
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
      --security/List?=null
  :
    if content-type == "application/x-www-form-urlencoded":
      if body: throw "body and form-params cannot be used together"
      body = serialize-form_ form-params

    to-apply/List := ?
    if authentication:
      to-apply = [authentication]
    else if security:
      to-apply = resolve-security authentications_ security
    else:
      to-apply = this.authentication ? [this.authentication] : []
    to-apply.do: | auth/Authentication |
      auth.apply-to-params
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
