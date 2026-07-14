// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import encoding.base64
import expect show *
import http

import openapi-runtime show *

main:
  test-api-key
  test-basic
  test-bearer
  test-oauth

test-api-key:
  query := []
  headers := http.Headers
  auth/Authentication := ApiKeyAuth --location="query" --param-name="api_key" --api-key="secret"
  auth.apply-to-params --query-params=query --header-params=headers
  expect-equals 1 query.size
  expect-equals "api_key=secret" (query[0] as QueryParam).stringify
  expect-null (headers.single "api_key")

  headers = http.Headers
  auth = ApiKeyAuth --location="header" --param-name="X-Api-Key" --api-key="secret" --api-key-prefix="Token"
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-equals "Token secret" (headers.single "X-Api-Key")

  // Cookie auth merges with an existing cookie.
  headers = http.Headers
  headers.set "Cookie" "session=abc"
  auth = ApiKeyAuth --location="cookie" --param-name="api_key" --api-key="secret"
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-equals "session=abc; api_key=secret" (headers.single "Cookie")

  headers = http.Headers
  auth = ApiKeyAuth --location="cookie" --param-name="api_key" --api-key="secret"
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-equals "api_key=secret" (headers.single "Cookie")

  // An empty key is a no-op.
  headers = http.Headers
  auth = ApiKeyAuth --location="header" --param-name="X-Api-Key"
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-null (headers.single "X-Api-Key")

test-basic:
  headers := http.Headers
  auth := HttpBasicAuth --username="user" --password="pass"
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-equals "Basic $(base64.encode "user:pass")" (headers.single "Authorization")

  // Missing credentials are a no-op.
  headers = http.Headers
  auth = HttpBasicAuth --username="user" --password=""
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-null (headers.single "Authorization")

test-bearer:
  headers := http.Headers
  auth/HttpBearerAuth := HttpBearerAuth.token "tok"
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-equals "Bearer tok" (headers.single "Authorization")

  // The callback variant fetches the token once and caches it.
  count := 0
  auth = HttpBearerAuth.callback::
    count++
    "cb-tok"
  headers = http.Headers
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-equals "Bearer cb-tok" (headers.single "Authorization")
  headers = http.Headers
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-equals "Bearer cb-tok" (headers.single "Authorization")
  expect-equals 1 count

test-oauth:
  headers := http.Headers
  auth := OAuth "tok"
  auth.apply-to-params --query-params=[] --header-params=headers
  expect-equals "Bearer tok" (headers.single "Authorization")
