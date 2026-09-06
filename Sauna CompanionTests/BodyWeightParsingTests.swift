//
//  BodyWeightParsingTests.swift
//  Sauna CompanionTests
//
//  The weight field is fed by a .decimalPad, whose separator depends on the
//  keyboard language. Three of the four languages this app ships in produce a
//  comma, so parsing has to accept both.
//

import Testing
import Foundation
@testable import Sauna_Companion

struct BodyWeightParsingTests {
    private let german = Locale(identifier: "de_DE")
    private let english = Locale(identifier: "en_US")
    /// Swiss German writes decimals with a dot, unlike Germany and Austria.
    private let swiss = Locale(identifier: "de_CH")

    @Test func acceptsADot() {
        #expect(AppSettings.parsedBodyWeightKg("80.5", locale: english) == 80.5)
    }

    @Test func acceptsACommaFromALocaleThatUsesOne() {
        // The bug this guards: Double("80,5") is nil, so the value was
        // silently dropped on German, Swedish and Finnish keyboards.
        #expect(AppSettings.parsedBodyWeightKg("80,5", locale: german) == 80.5)
    }

    @Test func acceptsTheOtherSeparatorToo() {
        // A hardware keyboard may produce a dot on a German phone, and the
        // stored value is written back with the locale separator — neither
        // should be refused.
        #expect(AppSettings.parsedBodyWeightKg("80.5", locale: german) == 80.5)
        #expect(AppSettings.parsedBodyWeightKg("80,5", locale: english) == 80.5)
    }

    @Test func acceptsAWholeNumberAndIgnoresSurroundingSpace() {
        #expect(AppSettings.parsedBodyWeightKg("80", locale: german) == 80)
        #expect(AppSettings.parsedBodyWeightKg(" 80 ", locale: german) == 80)
    }

    @Test func rejectsAnEmptyOrNonNumericString() {
        #expect(AppSettings.parsedBodyWeightKg("", locale: german) == nil)
        #expect(AppSettings.parsedBodyWeightKg("   ", locale: german) == nil)
        #expect(AppSettings.parsedBodyWeightKg("kg", locale: german) == nil)
    }

    @Test func rejectsValuesOutsideThePlausibleRange() {
        let low = AppSettings.bodyWeightRangeKg.lowerBound
        let high = AppSettings.bodyWeightRangeKg.upperBound

        #expect(AppSettings.parsedBodyWeightKg("\(low - 1)", locale: english) == nil)
        #expect(AppSettings.parsedBodyWeightKg("\(high + 1)", locale: english) == nil)
        #expect(AppSettings.parsedBodyWeightKg("0", locale: english) == nil)
        #expect(AppSettings.parsedBodyWeightKg("-80", locale: english) == nil)
    }

    @Test func acceptsBothEndsOfTheRange() {
        let low = AppSettings.bodyWeightRangeKg.lowerBound
        let high = AppSettings.bodyWeightRangeKg.upperBound

        #expect(AppSettings.parsedBodyWeightKg("\(low)", locale: english) == low)
        #expect(AppSettings.parsedBodyWeightKg("\(high)", locale: english) == high)
    }

    @Test func displayTextRoundTripsThroughTheParser() {
        for locale in [german, english, swiss] {
            let text = AppSettings.bodyWeightText(80.5, locale: locale)
            #expect(AppSettings.parsedBodyWeightKg(text, locale: locale) == 80.5)
        }
    }

    @Test func displayTextUsesTheLocaleSeparator() {
        #expect(AppSettings.bodyWeightText(80.5, locale: german) == "80,5")
        #expect(AppSettings.bodyWeightText(80.5, locale: english) == "80.5")
        #expect(AppSettings.bodyWeightText(80.5, locale: swiss) == "80.5")
        #expect(AppSettings.bodyWeightText(80, locale: german) == "80")
    }
}
