defmodule Frestyl.Search do
  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Media.{Channel, Room, Message, File}
  alias Frestyl.Accounts.User

  @max_results 10

  def search(query_string, user \\ nil) do
    tsquery = sanitize_query(query_string)

    %{
      channels: search_channels(tsquery, user, @max_results),
      rooms: search_rooms(tsquery, user, @max_results),
      messages: search_messages(tsquery, user, @max_results),
      files: search_files(tsquery, user, @max_results)
    }
  end

  defp sanitize_query(query_string) do
    query_string
    |> String.replace(~r/[!&|:()\[\]<>]/, " ")
    |> String.split()
    |> Enum.join(" & ")
  end

  defp search_channels(tsquery, user, limit) do
    query =
      from c in Channel,
        where: fragment("? @@ to_tsquery('english', ?)", c.search_vector, ^tsquery),
        order_by: [desc: fragment("ts_rank(?, to_tsquery('english', ?))", c.search_vector, ^tsquery)],
        limit: ^limit

    filtered =
      if user do
        from c in query,
          where:
            c.is_public == true or
              fragment(
                "EXISTS (SELECT 1 FROM channel_memberships WHERE channel_memberships.channel_id = ? AND channel_memberships.user_id = ?)",
                c.id, ^user.id
              )
      else
        from c in query,
          where: c.is_public == true
      end

    Repo.all(filtered)
  end

  defp search_rooms(tsquery, user, limit) do
    query =
      from r in Room,
        join: c in assoc(r, :channel),
        where: fragment("? @@ to_tsquery('english', ?)", r.search_vector, ^tsquery),
        order_by: [desc: fragment("ts_rank(?, to_tsquery('english', ?))", r.search_vector, ^tsquery)],
        limit: ^limit,
        select: r,
        preload: [channel: c]

    filtered =
      if user do
        from r in query,
          join: c in assoc(r, :channel),
          where:
            c.is_public == true or
              fragment(
                "EXISTS (SELECT 1 FROM channel_memberships WHERE channel_memberships.channel_id = ? AND channel_memberships.user_id = ?)",
                c.id, ^user.id
              )
      else
        from r in query,
          join: c in assoc(r, :channel),
          where: c.is_public == true
      end

    Repo.all(filtered)
  end

  defp search_messages(tsquery, user, limit) do
    query =
      from m in Message,
        join: r in assoc(m, :room),
        join: c in assoc(r, :channel),
        where: fragment("? @@ to_tsquery('english', ?)", m.search_vector, ^tsquery),
        order_by: [desc: fragment("ts_rank(?, to_tsquery('english', ?))", m.search_vector, ^tsquery)],
        limit: ^limit,
        select: m,
        preload: [room: {r, channel: c}]

    filtered =
      if user do
        from m in query,
          join: r in assoc(m, :room),
          join: c in assoc(r, :channel),
          where:
            c.is_public == true or
              fragment(
                "EXISTS (SELECT 1 FROM channel_memberships WHERE channel_memberships.channel_id = ? AND channel_memberships.user_id = ?)",
                c.id, ^user.id
              )
      else
        from m in query,
          join: r in assoc(m, :room),
          join: c in assoc(r, :channel),
          where: c.is_public == true
      end

    Repo.all(filtered)
  end

  defp search_files(tsquery, user, limit) do
    query =
      from f in File,
        join: c in assoc(f, :channel),
        where: fragment("? @@ to_tsquery('english', ?)", f.search_vector, ^tsquery),
        order_by: [desc: fragment("ts_rank(?, to_tsquery('english', ?))", f.search_vector, ^tsquery)],
        limit: ^limit,
        select: f,
        preload: [channel: c]

    filtered =
      if user do
        from f in query,
          join: c in assoc(f, :channel),
          where:
            c.is_public == true or
              fragment(
                "EXISTS (SELECT 1 FROM channel_memberships WHERE channel_memberships.channel_id = ? AND channel_memberships.user_id = ?)",
                c.id, ^user.id
              )
      else
        from f in query,
          join: c in assoc(f, :channel),
          where: c.is_public == true
      end

    Repo.all(filtered)
  end
end
