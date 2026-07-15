// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import expect show *

import openapi-runtime show *

main:
  test-resolve-security

test-resolve-security:
  key-auth := ApiKeyAuth --location="header" --param-name="X-API-KEY" --api-key="k"
  bearer-auth := HttpBearerAuth.token "t"
  auths := {
    "api_key": key-auth,
    "bearer": bearer-auth,
  }

  // The first satisfied alternative wins.
  resolved := resolve-security auths [["api_key"]]
  expect-equals 1 resolved.size
  expect (identical key-auth resolved[0])

  // All schemes of an alternative are applied (AND).
  resolved = resolve-security auths [["api_key", "bearer"]]
  expect-equals 2 resolved.size

  // Unsatisfiable alternatives are skipped (OR).
  resolved = resolve-security auths [["missing"], ["bearer"]]
  expect-equals 1 resolved.size
  expect (identical bearer-auth resolved[0])

  // A partially-configured alternative is not satisfied.
  resolved = resolve-security auths [["api_key", "missing"], ["bearer"]]
  expect-equals 1 resolved.size
  expect (identical bearer-auth resolved[0])

  // An empty alternative makes authentication optional.
  resolved = resolve-security {:} [["api_key"], []]
  expect resolved.is-empty

  // No satisfiable alternative and none optional: throws.
  expect-throw "AUTHENTICATION_MISSING":
    resolve-security {:} [["api_key"]]
