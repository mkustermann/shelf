## 0.6.4+3

* Support `http_parser` 2.0.0.

## 0.6.4+2

* Fix a bug where the `Content-Type` header didn't interact properly with the
  `encoding` parameter for `new Request()` and `new Response()` if it wasn't
  lowercase.

## 0.6.4+1

* When the `shelf_io` adapter detects an error, print the request context as
  well as the error itself.

## 0.6.4

* Add a `Server` interface representing an adapter that knows its own URL.

* Add a `ServerHandler` class that exposes a `Server` backed by a `Handler`.

* Add an `IOServer` class that implements `Server` in terms of `dart:io`'s
  `HttpServer`.

## 0.6.3+1

* Cleaned up handling of certain `Map` instances and related dependencies.

## 0.6.3

* Messages returned by `Request.change()` and `Response.change()` are marked
  read whenever the original message is read, and vice-versa. This means that
  it's possible to read a message on which `change()` has been called and to
  call `change()` on a message more than once, as long as `read()` is called on
  only one of those messages.

## 0.6.2+1

* Support `http_parser` 1.0.0.

## 0.6.2

* Added a `body` named argument to `change` method on `Request` and `Response`.

## 0.6.1+3

* Updated minimum SDK to `1.9.0`.

* Allow an empty `url` parameter to be passed in to `new Request()`. This fits
  the stated semantics of the class, and should not have been forbidden.

## 0.6.1+2

* `logRequests` outputs a better message a request has a query string.

## 0.6.1+1

* Don't throw a bogus exception for `null` responses.

## 0.6.1

* `shelf_io` now takes a `"shelf.io.buffer_output"` `Response.context` parameter
  that controls `HttpResponse.bufferOutput`.

* Fixed spelling errors in README and code comments.

## 0.6.0

**Breaking change:** The semantics of `Request.scriptName` and
[`Request.url`][url] have been overhauled, and the former has been renamed to
[`Request.handlerPath`][handlerPath]. `handlerPath` is now the root-relative URL
path to the current handler, while `url`'s path is the relative path from the
current handler to the requested. The new semantics are easier to describe and
to understand.

[url]: http://www.dartdocs.org/documentation/shelf/latest/index.html#shelf/shelf.Request@id_url
[handlerPath]: http://www.dartdocs.org/documentation/shelf/latest/index.html#shelf/shelf.Request@id_handlerPath

Practically speaking, the main difference is that the `/` at the beginning of
`url`'s path has been moved to the end of `handlerPath`. This makes `url`'s path
easier to parse using the `path` package.

[`Request.change`][change]'s handling of `handlerPath` and `url` has also
changed. Instead of taking both parameters separately and requiring that the
user manually maintain all the associated guarantees, it now takes a single
`path` parameter. This parameter is the relative path from the current
`handlerPath` to the next one, and sets both `handlerPath` and `url` on the new
`Request` accordingly.

[change]: http://www.dartdocs.org/documentation/shelf/latest/index.html#shelf/shelf.Request@id_change

## 0.5.7

* Updated `Request` to support the `body` model from `Response`.

## 0.5.6

* Fixed `createMiddleware` to only catch errors if `errorHandler` is provided.

* Updated `handleRequest` in `shelf_io` to more gracefully handle errors when
  parsing `HttpRequest`.

## 0.5.5+1

* Updated `Request.change` to include the original `onHijack` callback if one
  exists.

## 0.5.5

* Added default body text for `Response.forbidden` and `Response.notFound` if
  null is provided.

* Clarified documentation on a number of `Response` constructors.

* Updated `README` links to point to latest docs on `www.dartdocs.org`.

## 0.5.4+3

* Widen the version constraint on the `collection` package.

## 0.5.4+2

* Updated headers map to use a more efficient case-insensitive backing store.

## 0.5.4+1

* Widen the version constraint for `stack_trace`.

## 0.5.4

* The `shelf_io` adapter now sends the `Date` HTTP header by default.

* Fixed logic for setting Server header in `shelf_io`.

## 0.5.3

* Add new named parameters to `Request.change`: `scriptName` and `url`.

## 0.5.2

* Add a `Cascade` helper that runs handlers in sequence until one returns a
  response that's neither a 404 nor a 405.

* Add a `Request.change` method that copies a request with new header values.

* Add a `Request.hijack` method that allows handlers to gain access to the
  underlying HTTP socket.

## 0.5.1+1

* Capture all asynchronous errors thrown by handlers if they would otherwise be
  top-leveled.

* Add more detail to the README about handlers, middleware, and the rules for
  implementing an adapter.

## 0.5.1

* Add a `context` map to `Request` and `Response` for passing data among
  handlers and middleware.

## 0.5.0+1

* Allow `scheduled_test` development dependency up to v0.12.0

## 0.5.0

* Renamed `Stack` to `Pipeline`.

## 0.4.0

* Access to headers for `Request` and `Response` is now case-insensitive.

* The constructor for `Request` has been simplified.

* `Request` now exposes `url` which replaces `pathInfo`, `queryString`, and
  `pathSegments`.

## 0.3.0+9

* Removed old testing infrastructure.

* Updated documentation address.

## 0.3.0+8

* Added a dependency on the `http_parser` package.

## 0.3.0+7

* Removed unused dependency on the `mime` package.

## 0.3.0+6

* Added a dependency on the `string_scanner` package.

## 0.3.0+5

* Updated `pubspec` details for move to Dart SDK.

## 0.3.0 2014-03-25

* `Response`
    * **NEW!** `int get contentLength`
    * **NEW!** `DateTime get expires`
    * **NEW!** `DateTime get lastModified`
* `Request`
    * **BREAKING** `contentLength` is now read from `headers`. The constructor
      argument has been removed.
    * **NEW!** supports an optional `Stream<List<int>> body` constructor argument.
    * **NEW!** `Stream<List<int>> read()` and
      `Future<String> readAsString([Encoding encoding])`
    * **NEW!** `DateTime get ifModifiedSince`
    * **NEW!** `String get mimeType`
    * **NEW!** `Encoding get encoding`

## 0.2.0 2014-03-06

* **BREAKING** Removed `Shelf` prefix from all classes.
* **BREAKING** `Response` has drastically different constructors.
* *NEW!* `Response` now accepts a body of either `String` or
  `Stream<List<int>>`.
* *NEW!* `Response` now exposes `encoding` and `mimeType`.

## 0.1.0 2014-03-02

* First reviewed release
