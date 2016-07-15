defmodule ThisData.Api do
  require Logger
  use HTTPoison.Base

  # Define our API endpoint host
  @host "https://api.thisdata.com"

  # Automatically prepend the host above onto our URL when we call the API
  # client
  def process_url(url) do
    @host <> url
  end

  # Get the ThisData API key from environment variables
  def api_key do
    System.get_env("THIS_DATA_API_KEY")
  end

  # Encode the request body to JSON format
  def process_request_body(body) do
    body
    |> Poison.encode!
  end

  # Decode the response body from JSON format.
  #
  # Note that because the ThisData API response is a `null` JSON response, we
  # need to just return `nil` in this situation rather than `Poison`'s error
  # response
  def process_response_body(body) do
    case Poison.decode(body) do
      {:ok, body} ->
        body
      {:error, :invalid} ->
        nil
    end
  end

  # Send the event to ThisData.
  #
  # The body is the request body specified here:
  # http://help.thisdata.com/docs/apiv1events
  #
  # This method will return `:ok` or `:error` depending on success and log what
  # is happening
  def send_event(body) do

    # Only proceed if the API key is present (see `api_key` above)
    if is_binary(api_key) do

      Logger.debug "making ThisData API request with body: " <> Kernel.inspect(body)

      # Start the API client Process. See
      # http://elixir-lang.org/getting-started/processes.html for more info.
      ThisData.Api.start

      # Use the text/json content type
      headers = %{"Content-Type" => "text/json"}

      # Make the API request and handle different response conditions
      case ThisData.Api.post("/v1/events.json?api_key=#{api_key}", body, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          Logger.debug "ThisData API request successful: " <> Kernel.inspect(body)
          :ok
        {:ok, %HTTPoison.Response{status_code: 404}} ->
          Logger.debug "ThisData API request returned Not Found"
          :error
        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.debug "ThisData API request failed for " <> Kernel.inspect(reason)
          :error
      end
    else
      Logger.warn "THIS_DATA_API_KEY not configured, skipping API request"
    end
  end

end
