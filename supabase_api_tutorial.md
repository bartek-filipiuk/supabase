# Working with a Supabase PostgREST API (via `cURL`)

Supabase uses `PostgREST` to automatically generate a RESTful API for your PostgreSQL database ([supabase.com](http://supabase.com)). This means every table or view in your schema gets its own API endpoint for Create, Read, Update, Delete (CRUD) operations. 

In this tutorial, we'll assume your API is running at the base URL `https://mybases.pl:8443` (for a self-hosted Supabase instance or a Supabase project). By default, the REST endpoints are under the path `/rest/v1/` ([supabase.com](http://supabase.com)), so a table named `youtube_transcription` would be accessible at:

```bash
https://mybases.pl:8443/rest/v1/youtube_transcription
```

We'll demonstrate how to authenticate using the `anon` API key and perform full CRUD operations on the `youtube_transcription` table using `curl`. We'll also cover how to apply filters, pagination, and sorting to your requests. Finally, we'll clarify whether you can perform schema changes (DDL) through this API.

## Authentication with API Key

All requests to the Supabase REST API must include an API key for authorization. Supabase provides an `anon` key (for public/unprivileged access) and a `service_role` key (for admin access). For our examples, we'll use the `anon` key. Include this key in two headers on each request: an `apikey` header and an `Authorization: Bearer` header ([apidog.com](http://apidog.com)). Typically, both headers carry the same key value (the `anon` JWT), unless you use a user-specific JWT for an authenticated user session. For example, to test the connection (retrieving all rows from `youtube_transcription`), you could run:

```bash
curl 'https://mybases.pl:8443/rest/v1/youtube_transcription?select=*' \
  -H "apikey: YOUR_SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY"
```

If the key is valid and your table's Row Level Security (RLS) policies allow access, you should get a `JSON` response (possibly an empty array `[]` if the table is empty). If the key is missing or incorrect, the request will be rejected (`HTTP 401/403`). In the next sections, we'll include the required headers in each `curl` example.

## Creating a Record (INSERT via POST)

To create a new record in a table, you send a `POST` request to the table's endpoint with a `JSON` body. The `JSON` keys should match the column names of the table. You must also set the `Content-Type: application/json` header to indicate you're sending `JSON` data. For example, suppose our `youtube_transcription` table has columns for a YouTube video ID and a transcript text. We can insert a new row like so:

```bash
curl 'https://mybases.pl:8443/rest/v1/youtube_transcription' \
  -X POST \
  -H "apikey: YOUR_SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{ 
        "video_id": "abc123", 
        "text": "Hello world, this is a sample transcription." 
      }'
```

Let's break down this request:

*   We `POST` to the `/youtube_transcription` endpoint.
*   Headers:
    *   `apikey` and `Authorization` with our key (as discussed).
    *   `Content-Type: application/json` to send `JSON`.
    *   `Prefer: return=representation` to ask the API to return the created record in the response. This header is optional, but without it the API will return a minimal response (usually just a `201 Created` status without the new record). By including it, we get the inserted row back in `JSON` ([apidog.com](http://apidog.com)), which is useful to retrieve auto-generated fields (like an `id` or `timestamp`).
*   The `-d` payload is a `JSON` object with the new record's data. In this example, we provide a `video_id` and `text` for the transcription. Any columns not provided will use their default values or `null`.

If the insert is successful, you should receive a `201` status. With `Prefer:return=representation`, the response body will contain the newly created row (including, for example, an auto-generated `id`). If there was a violation (e.g., a `NOT NULL` field missing or a unique constraint violation), you'll get an error response describing the issue.

## Reading Records (SELECT via GET)

Reading data is done with `GET` requests to the table endpoint. A basic `GET` request to the table URL will return all rows visible to your role (subject to any RLS policies). You can retrieve specific rows or subsets of columns using query parameters. For example, to fetch all transcriptions (all columns) from the table:

```bash
curl 'https://mybases.pl:8443/rest/v1/youtube_transcription?select=*' \
  -H "apikey: YOUR_SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY"
```

Here we use the `select=*` query parameter to explicitly select all columns. (In `PostgREST`, if you omit `select`, it returns all columns by default, but it's good practice to use `select` especially when joining or limiting fields.) Often, you'll want to retrieve specific records. You can filter results by adding conditions as query parameters. For example, if your table has an `id` column (primary key), you can get a specific transcription by ID:

```bash
curl 'https://mybases.pl:8443/rest/v1/youtube_transcription?id=eq.1&select=*' \
  -H "apikey: YOUR_SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY"
```

This adds `?id=eq.1` to filter where `id = 1`. The response would be an array with the matching record (or an empty array if none match). Supabase (`PostgREST`) returns `JSON` arrays for results, or a single object if you request a single row by using a `LIMIT 1` or using the `Accept: application/vnd.pgrst.object+json` header (not shown here). Typically, you'll get an array of results even if one object matches the filter. Note: Multiple query conditions can be added (they are `ANDed` by default). We'll cover more filtering options (like ranges, search patterns, etc.) in the section on filtering below.

## Updating a Record (UPDATE via PATCH)

To update existing records, you can use `PATCH` (for partial updates) or `PUT` (to replace entire records). In most cases, `PATCH` is preferred to update only specified fields. The request is sent to the table endpoint with query params to filter the target row(s), and a `JSON` body of the fields to change. For example, to update the transcription text of the record with `id = 1`:

```bash
curl 'https://mybases.pl:8443/rest/v1/youtube_transcription?id=eq.1' \
  -X PATCH \
  -H "apikey: YOUR_SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{ "text": "Hello world, this transcription has been updated." }'
```

In this request:

*   We target `/youtube_transcription?id=eq.1` to apply the update only to the row with `id 1`. (If you omit a filter, all rows would be updated – so always include a filter such as the primary key or some condition to avoid mass updates.)
*   The method is `PATCH` and we provide a `JSON` body with only the fields we want to change (here, just the `text` field).
*   Headers:
    *   `Content-Type: application/json` (for the `JSON` body).
    *   We again use `Prefer: return=representation` so that the response will return the updated record (useful to verify the changes or get computed fields) ([apidog.com](http://apidog.com)). Without this, a successful update returns a `204 No Content` status with no body.

If the request is successful, you'll get either a `200 OK` with the updated record (if using `return=representation`) or `204 No Content`. If no record matched the filter, you'll get a `204 No Content` with an empty response (meaning nothing was updated). If the filter matched multiple records, all those will be updated (the response would include all updated records if requested). You can limit the number of rows affected by adding a `limit` and `order` clause (covered below in Filtering/Pagination) to, for example, update only the first matching row.

## Deleting a Record (DELETE)

To remove records, you send a `DELETE` request to the table endpoint, again with a filter to specify which record(s) to delete. Typically you filter by the primary key or another unique identifier. For example, to delete the transcription with `id = 1`:

```bash
curl 'https://mybases.pl:8443/rest/v1/youtube_transcription?id=eq.1' \
  -X DELETE \
  -H "apikey: YOUR_SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY"
```

We omit `Content-Type` since there's no request body for `DELETE`. This will delete the row where `id = 1`, if it exists and if your role has permission to delete it. On success, you'll typically get a `204 No Content` response (and the record will be gone). If you want to get confirmation of what was deleted, you can include `Prefer: return=representation` on the `DELETE` request as well. In that case, if a row is deleted, the API will return a `200 OK` with the deleted row's data in the response ([apidog.com](http://apidog.com)). (If no rows match the filter, you'd get a `204` and an empty response.) **Warning:** As with updates, make sure to use a filter. If you accidentally call `DELETE` on the table without a condition, all rows could be deleted (if your auth role permits it). `PostgREST` does allow specifying `?id=eq.*` to match all rows ([devhunt.org](http://devhunt.org)), but use this with extreme caution (or not at all).

## Filtering, Pagination, and Sorting Queries

One of the strengths of `PostgREST` (and Supabase's auto-API) is the ability to refine your requests with query parameters for filtering, selecting columns, ordering, and pagination. Here are some of the key query options available:

*   **Selecting specific columns:** Use `select` query parameter to control which columns (or nested relationships) are returned. For example: `?select=id,video_id,text` will fetch only those columns instead of all. (Use `select=*` for all columns) ([apidog.com](http://apidog.com)).
*   **Filtering results:** Add conditions as query params in the form `column=operator.value`. For example, `?video_id=eq.abc123` returns rows where `video_id = 'abc123'`. You can use a variety of operators besides equality:
    *   `eq` (equal to), `neq` (not equal),
    *   `gt` / `gte` (greater than / greater or equal),
    *   `lt` / `lte` (less than / less or equal),
    *   `like` (pattern match, case-sensitive), `ilike` (case-insensitive like),
    *   `in` (one of a list of values, e.g. `?status=in.(active,pending)`),
    *   `is` (check for exact `IS` conditions like `NULL`, e.g. `?text=is.null` to get rows where `text` is `NULL`),
    *   and more ([apidog.com](http://apidog.com)).
*   **Combining multiple filters:** You can include multiple conditions (e.g. `?video_id=eq.abc123&language=eq.en`). By default, multiple filters are combined with logical `AND`. For `OR` logic, you can use the special `or` query parameter. For example: `?or=(language.eq.en,language.eq.fr)` would fetch rows where language is either 'en' or 'fr'. You can even group conditions with `and/or` and `not` for more complex logic ([postgrest.org](http://postgrest.org)). If no filter is provided at all, the request will return all rows (up to any limits).
*   **Ordering (sorting):** Use the `order` parameter. For example: `?order=video_id.asc` or `?order=created_at.desc` to sort by a column ascending or descending ([apidog.com](http://apidog.com)). You can sort by multiple columns by comma-separating them (e.g. `?order=category.asc,created_at.desc`). By default, `null` values sort as if largest; you can append `.nullslast` or `.nullsfirst` to specify where `nulls` should appear ([apidog.com](http://apidog.com)) ([stackoverflow.com](http://stackoverflow.com)). For example: `?order=created_at.desc.nullslast`.
*   **Pagination (limit/offset):** By default, a `GET` could return all matching rows, but you can limit the result set. Use `limit` and `offset` parameters for offset-based pagination. For example: `?limit=10&offset=0` will return the first 10 rows; `?limit=10&offset=10` would get the next 10 ([apidog.com](http://apidog.com)). If you only use `limit` without `offset`, it's like `offset=0`. There is also support for ranged requests via HTTP headers (using `Range` or `Range-Unit` headers) as an alternative to `limit/offset` ([postgrest.org](http://postgrest.org)) ([postgrest.org](http://postgrest.org)), but using `limit` and `offset` in the URL is simpler for most cases.
*   **Counting total rows:** When using pagination, you often want the total number of rows available. The API can return this in a `Content-Range` header if requested. To get it, include the header `Prefer: count=exact` (or `count=planned/estimated` for performance) in your `GET` request ([postgrest.org](http://postgrest.org)). The response will then have a header `Content-Range: {start}-{end}/{total}`, where `{total}` is the total matching rows. This helps in implementing page indicators (e.g., "showing 11–20 of 100 items").

All the above query options can be combined in a single request. For instance, suppose we want to find transcripts that contain the word "hello" in their `text`, sorted by newest first, returning only 5 at a time (for pagination). Assuming our table has an `id` that increases with newer entries or a `created_at` timestamp, we could do:

```bash
curl 'https://mybases.pl:8443/rest/v1/youtube_transcription?text=ilike.%25hello%25&order=id.desc&limit=5&offset=0' \
  -H "apikey: YOUR_SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Prefer: count=exact"
```

Let's decode that URL:

*   `text=ilike.%25hello%25` filters rows where the `text` column `ilike '%hello%'` (the `%25` is URL-encoded `%` sign).
*   `order=id.desc` sorts results by `id` in descending order (so presumably newest first).
*   `limit=5` restricts to 5 records.
*   `offset=0` starts at the first page (0 offset).
*   We also sent `Prefer: count=exact` so the response headers include the total count of matching rows (which doesn't affect the `JSON` body, but helps our client know how many results exist in total). This flexibility allows you to query your data in many ways without writing any custom endpoints – you leverage the database query capabilities directly via the API.

## Calling Stored Procedures (RPC) (Optional)

*(Optional section, if relevant to the user)* Apart from tables, Supabase's REST API also exposes `PostgreSQL` functions (a.k.a. stored procedures) that are marked as "immutable" or "stable" (or if you configure otherwise). These appear under a special `RPC` endpoint. For example, a Postgres function `hello_world()` would be callable at `POST /rest/v1/rpc/hello_world`. You would include any function arguments as a `JSON` object in the request body. Stored procedures can be used to perform complex operations or logic on the server side. However, note that calling a function via the REST API still requires proper authentication and adheres to any security definitions you set (e.g., arguments must pass RLS checks if the function queries tables). For detailed usage of `RPC` endpoints, refer to Supabase/PostgREST documentation. (The question didn't explicitly ask for `RPC`, so this section can be omitted if focusing strictly on table `CRUD`. It's mentioned here for completeness.)

## Limitations: Schema Changes (DDL) via REST API

One important aspect to understand is that the auto-generated REST API is designed for data operations (`CRUD` on tables, calling functions), not for managing the database schema. You cannot create or alter tables, columns, or roles through the Supabase REST API. In other words, `DDL` (Data Definition Language) commands like `CREATE TABLE` are not supported via the `PostgREST` endpoints by default. The Supabase team recommends performing such tasks via `SQL` scripts or the Supabase Dashboard UI ([supabase.com](http://supabase.com)). For example, you can use the `SQL editor` in the Supabase dashboard or connect to the database directly (e.g., with `psql` or a migration tool) to execute `DDL` commands. In fact, attempting to create a table through the REST API will simply not work – no endpoint exists for it. Some advanced users have created Postgres functions to run `DDL` commands and then called those via the `RPC` mechanism, but this is generally discouraged ([github.com](http://github.com)). Opening up `DDL` via an API can be dangerous and is usually unnecessary in a well-planned schema. If you absolutely must use an API for `DDL`, you'd need to create a custom endpoint or a secure function (with a lot of caution and proper privileges) on your own. For almost all cases, stick to managing the schema through migrations or the provided interface, and use the REST API for data operations on that schema.

## Conclusion

In this tutorial, we've seen how to interact with a Supabase-hosted `PostgREST` API using `cURL` for a sample table `youtube_transcription`. We covered authenticating with the `anon` key, and demonstrated `CRUD` operations: inserting new rows (`POST`), reading data (`GET` with filters), updating existing records (`PATCH`), and deleting records (`DELETE`). We also explored how to refine queries with filters, sorting, and pagination parameters to retrieve exactly the data you need. With this knowledge, you can build front-ends or scripts to manage your Supabase data directly over `HTTP`. The Supabase auto-generated API provides a quick and flexible way to work with your database, all while enforcing the security rules you've set at the database level. For further details, you can refer to the Supabase documentation and the `PostgREST` documentation for advanced usage. Happy coding!

### Sources:

- [PostgREST Documentation](https://postgrest.org)
- [Supabase REST API Docs](https://supabase.com/docs/guides/api)
- [Supabase PostgREST Query Filters](https://supabase.com/docs/guides/api/rest/query-filters)
- [Supabase Auth and API Keys](https://supabase.com/docs/guides/auth#api-keys)
- [Supabase RPC (Remote Procedure Call)](https://supabase.com/docs/guides/api/rest/rpc)
- [Supabase Count and Pagination](https://supabase.com/docs/guides/api/rest/pagination)
- [Supabase HTTP Headers Reference](https://supabase.com/docs/guides/api/rest/http)