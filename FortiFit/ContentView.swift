//
//  ContentView.swift
//  FortiFit
//
//  Created by cameron saucier on 3/19/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: selectedTab)
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("HOME")
                }
                .tag(0)
                .accessibilityIdentifier(AccessibilityID.tabBarHome)

            WorkoutListView(selectedTab: selectedTab)
                .tabItem {
                    Image(systemName: "dumbbell")
                    Text("WORKOUTS")
                }
                .tag(1)
                .accessibilityIdentifier(AccessibilityID.tabBarWorkouts)

            PlanView(selectedTab: selectedTab)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("PLAN")
                }
                .tag(2)
                .accessibilityIdentifier(AccessibilityID.tabBarPlan)

            FortiFitProgressView(selectedTab: selectedTab)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("TRENDS")
                }
                .tag(3)
                .accessibilityIdentifier(AccessibilityID.tabBarTrends)

            GoalsView(selectedTab: selectedTab)
                .tabItem {
                    Label {
                        Text("GOALS")
                    } icon: {
                        Image(systemName: "target")
                    }
                }
                .tag(4)
                .accessibilityIdentifier(AccessibilityID.tabBarGoals)
        }
        .tint(FortiFitColors.primaryAccent)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToPlanTab)) { _ in
            selectedTab = 2
        }
    }
}

#Preview {
    ContentView()
}
