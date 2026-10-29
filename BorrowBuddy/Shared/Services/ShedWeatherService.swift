import Foundation

struct ShedWeather: Equatable {
    let temperatureCelsius: Double
    let code: Int

    var condition: String {
        switch code {
        case 0: "clear"
        case 1, 2, 3: "cloudy"
        case 45, 48: "foggy"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: "rainy"
        case 71, 73, 75, 77, 85, 86: "snowy"
        case 95, 96, 99: "stormy"
        default: "mixed"
        }
    }

    var summary: String {
        "\(Int(temperatureCelsius.rounded()))°C and \(condition) at your shed"
    }
}

enum ShedWeatherService {
    static let endpoint = URL(string: "https://api.open-meteo.com/v1/forecast")!

    static func requestURL(latitude: Double, longitude: Double) -> URL? {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code")
        ]
        return components?.url
    }

    static func weather(from data: Data) throws -> ShedWeather {
        let payload = try JSONDecoder().decode(OpenMeteoForecast.self, from: data)
        return ShedWeather(temperatureCelsius: payload.current.temperature2m, code: payload.current.weatherCode)
    }

    static func current(latitude: Double, longitude: Double, session: URLSession = .shared) async throws -> ShedWeather {
        guard let url = requestURL(latitude: latitude, longitude: longitude) else {
            throw CommunityError.invalidInput("That shed location cannot be used for a forecast.")
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CommunityError.unavailable
        }
        return try weather(from: data)
    }
}

private struct OpenMeteoForecast: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    let current: Current
}
