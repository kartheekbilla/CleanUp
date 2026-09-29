//
//  StorageWidgetLiveActivity.swift
//  StorageWidget
//
//  Created by Kartheek Billa on 29/09/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StorageWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct StorageWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StorageWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension StorageWidgetAttributes {
    fileprivate static var preview: StorageWidgetAttributes {
        StorageWidgetAttributes(name: "World")
    }
}

extension StorageWidgetAttributes.ContentState {
    fileprivate static var smiley: StorageWidgetAttributes.ContentState {
        StorageWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: StorageWidgetAttributes.ContentState {
         StorageWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: StorageWidgetAttributes.preview) {
   StorageWidgetLiveActivity()
} contentStates: {
    StorageWidgetAttributes.ContentState.smiley
    StorageWidgetAttributes.ContentState.starEyes
}
