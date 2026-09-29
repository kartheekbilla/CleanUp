//
//  StorageWidgetBundle.swift
//  StorageWidget
//
//  Created by Kartheek Billa on 29/09/26.
//

import WidgetKit
import SwiftUI

@main
struct StorageWidgetBundle: WidgetBundle {
    var body: some Widget {
        StorageWidget()
        StorageWidgetControl()
        StorageWidgetLiveActivity()
    }
}
