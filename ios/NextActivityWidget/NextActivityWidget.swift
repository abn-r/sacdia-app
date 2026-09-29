import SwiftUI
import WidgetKit

private let widgetGroupId = "group.com.sacdia.app"

struct NextActivityEntry: TimelineEntry {
  let date: Date
  let title: String
  let weekday: String
  let day: String
  let month: String
  let timeLabel: String
  let dateLabel: String
  let clubName: String
  let activityId: String

  var hasDatePlate: Bool {
    !day.isEmpty
  }

  var metaLine: String {
    let structured = [timeLabel, clubName].filter { !$0.isEmpty }.joined(separator: " · ")
    if !structured.isEmpty { return structured }
    return dateLabel
  }
}

struct NextActivityProvider: TimelineProvider {
  func placeholder(in context: Context) -> NextActivityEntry {
    NextActivityEntry(
      date: Date(),
      title: "Caminata al parque",
      weekday: "SÁB",
      day: "27",
      month: "SEP",
      timeLabel: "09:00",
      dateLabel: "sáb 27 sep · 09:00",
      clubName: "Tu club",
      activityId: ""
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (NextActivityEntry) -> Void) {
    let defaults = UserDefaults(suiteName: widgetGroupId)
    let title = defaults?.string(forKey: "activity_title") ?? ""
    let dateLabel = defaults?.string(forKey: "activity_date") ?? ""
    var weekday = defaults?.string(forKey: "activity_weekday") ?? ""
    var day = defaults?.string(forKey: "activity_day") ?? ""
    var month = defaults?.string(forKey: "activity_month") ?? ""
    var timeLabel = defaults?.string(forKey: "activity_time") ?? ""
    let clubName = defaults?.string(forKey: "activity_club") ?? ""
    let activityId = defaults?.string(forKey: "activity_id") ?? ""

    if day.isEmpty {
      let legacy = parseLegacyDate(dateLabel)
      weekday = legacy.weekday
      day = legacy.day
      month = legacy.month
      if timeLabel.isEmpty { timeLabel = legacy.time }
    }

    let entry: NextActivityEntry
    if title.isEmpty && context.isPreview {
      entry = placeholder(in: context)
    } else {
      entry = NextActivityEntry(
        date: Date(),
        title: title.isEmpty ? "Sin actividades programadas" : title,
        weekday: weekday,
        day: day,
        month: month,
        timeLabel: timeLabel,
        dateLabel: dateLabel,
        clubName: clubName,
        activityId: activityId
      )
    }
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NextActivityEntry>) -> Void) {
    getSnapshot(in: context) { entry in
      completion(Timeline(entries: [entry], policy: .atEnd))
    }
  }
}

private func parseLegacyDate(_ label: String) -> (weekday: String, day: String, month: String, time: String) {
  let chunks = label.components(separatedBy: " · ")
  let time = chunks.count > 1 ? chunks[1].trimmingCharacters(in: .whitespaces) : ""
  let tokens = chunks[0]
    .split(separator: " ")
    .map { $0.replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces) }
    .filter { !$0.isEmpty }
  guard tokens.count >= 3, Int(tokens[1]) != nil else {
    return ("", "", "", time)
  }
  return (tokens[0].uppercased(), tokens[1], tokens[2].uppercased(), time)
}

struct NextActivityWidgetView: View {
  var entry: NextActivityProvider.Entry
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.widgetFamily) private var family

  private var ink: Color { Color.white }

  private var inkMuted: Color { Color.white.opacity(0.92) }

  private var whenLine: String {
    [entry.weekday, entry.month].filter { !$0.isEmpty }.joined(separator: " · ")
  }

  private var posterColors: [Color] {
    if colorScheme == .dark {
      return [
        Color(red: 0.60, green: 0.20, blue: 0.16),
        Color(red: 0.43, green: 0.13, blue: 0.11),
        Color(red: 0.24, green: 0.06, blue: 0.05),
      ]
    }
    return [
      Color(red: 0.824, green: 0.243, blue: 0.188),
      Color(red: 0.769, green: 0.204, blue: 0.149),
      Color(red: 0.557, green: 0.118, blue: 0.094),
    ]
  }

  private var launchURL: URL? {
    guard !entry.activityId.isEmpty else { return nil }
    return URL(string: "io.sacdia.app://activity/\(entry.activityId)?homeWidget")
  }

  var body: some View {
    let content = Group {
      if family == .systemMedium && entry.hasDatePlate {
        mediumContent
      } else {
        smallContent
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

    if #available(iOS 17.0, *) {
      content
        .containerBackground(for: .widget) { surface }
        .widgetURL(launchURL)
    } else {
      content
        .padding(12)
        .background(surface)
        .widgetURL(launchURL)
    }
  }

  @ViewBuilder
  private var surface: some View {
    if entry.hasDatePlate {
      ZStack {
        LinearGradient(
          colors: posterColors,
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.14),
            Color.clear,
          ],
          startPoint: .top,
          endPoint: UnitPoint(x: 0.5, y: 0.32)
        )
      }
    } else {
      Color(red: 0.16, green: 0.09, blue: 0.08)
    }
  }

  private var smallContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      if entry.hasDatePlate {
        Text(entry.day)
          .font(.system(size: 46, weight: .bold))
          .foregroundColor(ink)
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        if !whenLine.isEmpty {
          Text(whenLine)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(inkMuted)
            .padding(.top, 1)
        }
      }

      Spacer(minLength: 8)

      Text(entry.title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(ink)
        .lineLimit(2)
        .minimumScaleFactor(0.85)

      if !entry.metaLine.isEmpty {
        Text(entry.metaLine)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(inkMuted)
          .lineLimit(1)
          .padding(.top, 2)
      }
    }
  }

  private var mediumContent: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 0) {
        Text(entry.day)
          .font(.system(size: 52, weight: .bold))
          .foregroundColor(ink)
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        if !whenLine.isEmpty {
          Text(whenLine)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(inkMuted)
        }
      }

      Rectangle()
        .fill(Color.white.opacity(0.28))
        .frame(width: 1)
        .padding(.vertical, 2)

      VStack(alignment: .leading, spacing: 4) {
        Text(entry.title)
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(ink)
          .lineLimit(2)
          .minimumScaleFactor(0.85)
        if !entry.metaLine.isEmpty {
          Text(entry.metaLine)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(inkMuted)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 0)
    }
  }
}

struct NextActivityWidget: Widget {
  let kind: String = "NextActivityWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: NextActivityProvider()) { entry in
      NextActivityWidgetView(entry: entry)
    }
    .configurationDisplayName("Próxima actividad")
    .description("La siguiente actividad de tu club")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
