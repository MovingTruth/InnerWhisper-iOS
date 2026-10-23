//
//  AnimatedAuroraBackground.swift
//  InnerWhisper
//

import SwiftUI

/// A beautiful, slowly animating gradient view to demonstrate custom ThemeBackgrounds.
struct AnimatedAuroraBackground: View {
    @State private var start = UnitPoint(x: 0, y: -2)
    @State private var end = UnitPoint(x: 4, y: 0)
    
    // Aurora-like colors
    let colors = [
        Color(red: 0.1, green: 0.2, blue: 0.4),
        Color(red: 0.4, green: 0.1, blue: 0.5),
        Color(red: 0.1, green: 0.5, blue: 0.6),
        Color(red: 0.3, green: 0.1, blue: 0.4)
    ]
    
    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: start,
            endPoint: end
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                start = UnitPoint(x: 1, y: -1)
                end = UnitPoint(x: 0, y: 2)
            }
        }
    }
}

#Preview {
    AnimatedAuroraBackground()
}
