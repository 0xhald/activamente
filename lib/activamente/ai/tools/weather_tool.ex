defmodule Activamente.AI.Tools.WeatherTool do
  @moduledoc """
  Tool for getting weather information from an external API.
  """

  @behaviour Activamente.AI.Tools.ToolBehaviour

  @impl true
  def get_definition do
    %{
      "type" => "function",
      "function" => %{
        "name" => "get_weather",
        "description" => "Get current weather information for a specified location",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "location" => %{
              "type" => "string",
              "description" =>
                "The city or location to get weather for (e.g., 'Mexico City', 'New York, NY')"
            },
            "units" => %{
              "type" => "string",
              "enum" => ["metric", "imperial"],
              "description" =>
                "Temperature units: metric (Celsius) or imperial (Fahrenheit). Default: metric"
            }
          },
          "required" => ["location"]
        }
      }
    }
  end

  @impl true
  def execute(args, _context) do
    location = Map.get(args, "location")
    units = Map.get(args, "units", "metric")

    # For demo purposes, we'll return mock weather data
    # In a real implementation, you would call a weather API like OpenWeatherMap

    case fetch_weather_data(location, units) do
      {:ok, weather_data} ->
        %{
          success: true,
          location: location,
          weather: weather_data,
          units: units
        }

        # {:error, reason} ->
        #   %{
        #     success: false,
        #     error: "Failed to get weather data: #{reason}"
        #   }
    end
  end

  # Mock weather data for demo - replace with real API call
  defp fetch_weather_data(location, units) do
    # This is a mock implementation
    # In production, you would call an actual weather API like:
    # https://api.openweathermap.org/data/2.5/weather?q={location}&appid={API_key}&units={units}

    temp_unit = if units == "metric", do: "°C", else: "°F"
    base_temp = if units == "metric", do: 22, else: 72

    mock_data = %{
      temperature: base_temp + :rand.uniform(10) - 5,
      temperature_unit: temp_unit,
      description: Enum.random(["sunny", "partly cloudy", "cloudy", "light rain"]),
      humidity: 45 + :rand.uniform(40),
      wind_speed: 5 + :rand.uniform(15),
      wind_unit: if(units == "metric", do: "m/s", else: "mph"),
      location: location,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, mock_data}
  end

  # Uncomment and modify this for real weather API integration:
  #
  # defp fetch_weather_data(location, units) do
  #   api_key = System.get_env("OPENWEATHER_API_KEY")
  #
  #   if not api_key do
  #     {:error, "Weather API key not configured"}
  #   else
  #     url = "https://api.openweathermap.org/data/2.5/weather"
  #
  #     params = %{
  #       q: location,
  #       appid: api_key,
  #       units: units
  #     }
  #
  #     case Req.get(url, params: params) do
  #       {:ok, %{status: 200, body: data}} ->
  #         weather_data = %{
  #           temperature: data["main"]["temp"],
  #           temperature_unit: if(units == "metric", do: "°C", else: "°F"),
  #           description: data["weather"] |> List.first() |> Map.get("description"),
  #           humidity: data["main"]["humidity"],
  #           wind_speed: data["wind"]["speed"],
  #           wind_unit: if(units == "metric", do: "m/s", else: "mph"),
  #           location: data["name"],
  #           timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
  #         }
  #         {:ok, weather_data}
  #
  #       {:ok, %{status: status}} ->
  #         {:error, "Weather API returned status #{status}"}
  #
  #       {:error, reason} ->
  #         {:error, "Request failed: #{inspect(reason)}"}
  #     end
  #   end
  # end
end
