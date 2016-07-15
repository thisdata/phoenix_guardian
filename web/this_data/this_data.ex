defmodule ThisData do
  require Logger

  # Track a log in event
  def track_log_in(conn, user) do
    Logger.debug "tracking log in"
    conn
    |> track("log-in", user)
  end

  # Track a log out event
  def track_log_out(conn, user) do
    Logger.debug "tracking log out"
    conn
    |> track("log-out", user)
  end

  # Track a log in denied event
  def track_log_in_denied(conn, auth) do
    Logger.debug "track log in denied"
    conn
    |> track("log-in-denied", nil, auth)
  end

  # Build a request body and send a track request via ThisData.Api
  #
  # This function takes a connection (conn), verb, and optionally user and auth.
  # The auth item contains credentials we can send where we don't know who the
  # user is (because they haven't successfully logged in).
  defp track(conn, verb, user \\ nil, auth \\ nil) do

    # Exact the user agent from the connection headers
    user_agents = Plug.Conn.get_req_header(conn, "user-agent")
    user_agent = List.first(user_agents)

    # Get the remote IP from the X-Forwarded-For header if present, so this
    # works as expected when behind a load balancer
    remote_ips = Plug.Conn.get_req_header(conn, "x-forwarded-for")
    remote_ip = List.first(remote_ips)

    # If there was nothing in X-Forarded-For, use the remote IP directly
    unless remote_ip do
      # Extract the remote IP from the connection
      remote_ip_as_tuple = conn.remote_ip

      # The remote IP is a tuple like `{127, 0, 0, 1}`, so we need join it into
      # a string for the API. Note that this works for IPv4 - IPv6 support is
      # exercise for the reader!
      remote_ip = Enum.join(Tuple.to_list(remote_ip_as_tuple), ".")
    end

    # Default values for our API attributes
    user_id = "anonymous"
    user_email = nil
    user_name = nil

    # If there is a user item, populate the API attributes with its details,
    # otherwise if there is an auth item grab the email from it
    cond do
      user ->
        user_id = user.id
        user_name = user.name
        user_email = user.email
      auth ->
        user_email = auth.info.email
    end

    # Construct the request body
    body = %{
      verb:       verb,
      ip:         remote_ip,
      user_agent: user_agent,
      user:       %{
        id:    user_id,
        email: user_email,
        name:  user_name
      }
    }

    # Send the event via ThisData.Api
    result = ThisData.Api.send_event(body)
    Logger.debug "Result: " <> Kernel.inspect(result)

    # Return the connection again, since we'll be calling this method via an
    # Elixir pipe operator - see
    # https://elixirschool.com/lessons/basics/pipe-operator/
    conn
  end

end