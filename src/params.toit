import encoding.url as url-encoding
import http
import .openapi-object

is-primitive-type value/any -> bool:
  return value is string or value is num or value is bool

class QueryParam:
  key/string
  value/any

  constructor .key .value:

  stringify -> string:
    return "$key=$value"

  url-encode -> string:
    encoded-key := url-encoding.encode key
    // The encoder only accepts strings/byte-arrays. Stringify primitive
    //   values (int, num, bool) so that e.g. `?limit=5` works.
    encoded-value := url-encoding.encode "$value"
    return "$encoded-key=$encoded-value"

encode-path-param -> string
    key/string
    value/any
    --style/string?=null
    --explode/bool=false
:
  if not style or style == "simple":
    return encode-param-simple_ value --explode=explode

  if style == "matrix" or style == "label":
    return encode-param-matrix-or-label_ key value --style=style --explode=explode

  throw "UNIMPLEMENTED"

encode-query-param -> List
    key/string
    value/any
    --style/string?=null
    --explode/bool=false
:
  if not style or style == "form":
    return encode-query-param-form_ key value --explode=explode

  if style == "spaceDelimited" or style == "pipeDelimited":
    return encode-query-param-delimited_ key value --style=style --explode=explode

  if style == "deepObject":
    return encode-query-param-deep-object_ key value --explode=explode

  throw "UNIMPLEMENTED"

encode-header-param -> none
    headers/http.Headers
    key/string
    value/any
    --style/string?=null
    --explode/bool=false
:
  headers.add key (encode-param-simple_ value --explode=explode)

encode-query-param-form_ key/string value/any --explode/bool -> List:
  if value is List:
    value-list := value as List
    if explode:
      return value-list.map: | item/any |
        if not is-primitive-type item: throw "UNIMPLEMENTED"
        param := QueryParam key item
    if not (value.every: | item | is-primitive-type item):
      throw "UNIMPLEMENTED"
    items-as-string := value-list.map: "$it"
    joined := items-as-string.join ","
    return [QueryParam key joined]

  if value is OpenapiObject:
    value = value.to-json

  if value is Map:
    value-map := value as Map
    if explode:
      result := []
      value-map.do: | k/string v |
        if not is-primitive-type v: throw "UNIMPLEMENTED"
        param := QueryParam k v
        result.add param
      return result

    items-as-strings := []
    value-map.do: | k/string v |
      if not is-primitive-type v: throw "UNIMPLEMENTED"
      items-as-strings.add "$k,$v"
    joined := items-as-strings.join ","
    return [QueryParam key joined]

  if not is-primitive-type value:
    throw "UNIMPLEMENTED"
  return [QueryParam key value]

encode-query-param-delimited_ key/string value/any --style/string --explode/bool -> List:
  delimiter := style == "spaceDelimited" ? " " : "|"
  if value is List:
    value-list := value as List
    if not (value-list.every: | item | is-primitive-type item):
      throw "UNIMPLEMENTED"
    items-as-strings := value-list.map: "$it"
    joined := items-as-strings.join delimiter
    return [QueryParam key joined]

  if value is OpenapiObject:
    value = value.to-json

  if value is Map:
    value-map := value as Map
    entries-as-strings := []
    value-map.do: | k/string v |
      if not is-primitive-type v: throw "UNIMPLEMENTED"
      entries-as-strings.add k
      entries-as-strings.add "$v"
    joined := entries-as-strings.join delimiter
    return [QueryParam key joined]

  throw "UNIMPLEMENTED"

encode-query-param-deep-object_ key/string value/any --explode/bool -> List:
  if value is OpenapiObject:
    value = value.to-json

  if value is not Map: throw "UNIMPLEMENTED"
  if not explode: throw "UNIMPLEMENTED"

  value-map := value as Map
  result := []
  value-map.do: | k/string v |
    if not is-primitive-type v: throw "UNIMPLEMENTED"
    param-key := "$(key)[$k]"
    param := QueryParam param-key v
    result.add param
  return result

encode-param-simple_ value/any --explode/bool -> string:
  if value is List:
    value-list := value as List
    if not (value-list.every: | item | is-primitive-type item):
      throw "UNIMPLEMENTED"
    items-as-strings := value-list.map: "$it"
    return items-as-strings.join ","

  if value is OpenapiObject:
    value = value.to-json

  if value is Map:
    value-map := value as Map
    entries-as-strings := []
    value-map.do: | k/string v |
      if not is-primitive-type v: throw "UNIMPLEMENTED"
      if explode:
        entries-as-strings.add "$k=$v"
      else:
        entries-as-strings.add k
        entries-as-strings.add "$v"
    return entries-as-strings.join ","

  if not is-primitive-type value:
    throw "UNIMPLEMENTED"

  return "$value"

encode-param-matrix-or-label_ key/string value/any --explode/bool --style/string -> string:
  if value == null: return style == "matrix" ? ";$key" : "."

  prefix := style == "matrix" ? ";$key=" : "."

  if is-primitive-type value:
    return "$prefix$value"

  if value is List:
    value-list := value as List
    if not (value-list.every: | item | is-primitive-type item):
      throw "UNIMPLEMENTED"
    items-as-strings := value-list.map: "$it"
    if style == "matrix" and not explode:
      joined := items-as-strings.join ","
      return "$prefix$joined"

    prefixed := items-as-strings.map: "$prefix$it"
    return prefixed.join ""

  if value is OpenapiObject:
    value = value.to-json

  if value is Map:
    value-map := value as Map
    if not (value-map.every: | k/string v | is-primitive-type v):
      throw "UNIMPLEMENTED"
    if style == "matrix" and not explode:
      entries-as-strings := []
      value-map.do: | k/string v |
        entries-as-strings.add k
        entries-as-strings.add "$v"
      joined := entries-as-strings.join ","
      return "$prefix$joined"
    if style == "matrix" and explode:
      // We lose the key and just prefix each key-value pair.
      parts := []
      value-map.do: | k/string v |
        parts.add ";$k=$v"
      return parts.join ""
    if style == "label" and not explode:
      entries-as-strings := []
      value-map.do: | k/string v |
        entries-as-strings.add k
        entries-as-strings.add "$v"
      return prefix + (entries-as-strings.join ".")
    if style == "label" and explode:
      parts := []
      value-map.do: | k/string v |
        parts.add ".$k=$v"
      return parts.join ""

  throw "UNIMPLEMENTED"
