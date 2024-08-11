//
//  AppTheme.swift
//  SatHunter
//
//  Created by Aleksandar Zdravković on 8/11/24.
//

import Foundation

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case lowContrast = "Low Contrast"

    var id: String { self.rawValue }
}

class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme = .system {
            didSet {
                saveTheme()
            }
        }

        init() {
            loadTheme()
        }
    
    func applyTheme() -> ColorScheme? {
        switch selectedTheme {
        case .system:
            return getSystemColorScheme()
        case .light:
            return .light
        case .dark:
            return .dark
        case .lowContrast:
            return .light // Apply a low contrast custom theme
        }
    }
    
    private func getSystemColorScheme() -> ColorScheme {
#if os(iOS)
        // For iOS, using UIKit
        let userInterfaceStyle = UITraitCollection.current.userInterfaceStyle
        return userInterfaceStyle == .dark ? .dark : .light
#elseif os(macOS)
        // For macOS, using AppKit
        let appearanceName = NSApp.effectiveAppearance.name
        return appearanceName == .darkAqua ? .dark : .light
#else
        // Default to light for unsupported platforms
        return .light
#endif
    }

    
    private func saveTheme() {
           UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
    }

    private func loadTheme() {
           if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
              let theme = AppTheme(rawValue: savedTheme) {
               selectedTheme = theme
           }
    }
}

struct LowContrastModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(.red)
            .background(Color(white: 0.95))
    }
}

extension View {
    func applyLowContrast() -> some View {
        self.modifier(LowContrastModifier())
    }
}
