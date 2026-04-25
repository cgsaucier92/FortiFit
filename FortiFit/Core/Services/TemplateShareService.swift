import Foundation
import SwiftData
import CoreImage.CIFilterBuiltins

#if os(iOS)
import UIKit
#endif

// MARK: - Payload Types

struct TemplatePayload: Codable {
    let v: Int
    let name: String
    let workoutType: String
    let durationMinutes: Int?
    let exercises: [ExercisePayload]
}

struct ExercisePayload: Codable {
    let exerciseName: String
    let sets: Int
    let reps: Int
    let weightKg: Double?
    let sortOrder: Int
}

// MARK: - TemplateShareService

enum TemplateShareService {
    /// Maximum URL size for QR code version 40, error correction M (binary mode).
    private static let maxQRBytes = 2331

    // MARK: - Encode

    /// Serializes a WorkoutTemplate into a `fitnavi://template?v=1&data=<base64url>` URL.
    /// Returns nil if the encoded URL exceeds the QR byte limit.
    static func encodeTemplate(_ template: WorkoutTemplate) -> URL? {
        let exercises = template.exerciseSets
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { set in
                ExercisePayload(
                    exerciseName: set.exerciseName,
                    sets: set.sets,
                    reps: set.reps,
                    weightKg: set.weightKg,
                    sortOrder: set.sortOrder
                )
            }

        let payload = TemplatePayload(
            v: 1,
            name: template.name,
            workoutType: template.workoutType,
            durationMinutes: template.durationMinutes,
            exercises: exercises
        )

        guard let jsonData = try? JSONEncoder().encode(payload) else { return nil }

        let base64url = jsonData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let urlString = "fitnavi://template?v=1&data=\(base64url)"

        guard urlString.utf8.count <= maxQRBytes else { return nil }
        return URL(string: urlString)
    }

    // MARK: - QR Code Generation

    #if os(iOS)
    /// Generates a QR code UIImage from a URL using CIQRCodeGenerator.
    /// Returns nil on failure.
    static func generateQRCode(from url: URL) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale to ~250pt
        let targetSize: CGFloat = 250
        let scaleX = targetSize / outputImage.extent.size.width
        let scaleY = targetSize / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    #endif

    // MARK: - Decode

    /// Parses a `fitnavi://template` URL and returns the decoded payload.
    /// Returns nil if any validation step fails.
    static func decodeTemplateURL(url: URL) -> TemplatePayload? {
        guard url.scheme == "fitnavi" else { return nil }
        guard url.host == "template" else { return nil }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value else {
            return nil
        }

        // Base64url decode
        var base64 = dataParam
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Re-add padding
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let jsonData = Data(base64Encoded: base64) else { return nil }
        guard let payload = try? JSONDecoder().decode(TemplatePayload.self, from: jsonData) else { return nil }

        // Validate version
        guard payload.v == 1 else { return nil }

        // Validate workout type
        guard payload.workoutType == "Strength Training" || payload.workoutType == "HIIT" else { return nil }

        return payload
    }

    // MARK: - Import

    /// Creates a WorkoutTemplate + TemplateExerciseSets from a decoded payload.
    @discardableResult
    static func importTemplate(payload: TemplatePayload, context: ModelContext) -> WorkoutTemplate {
        let resolvedName = resolveTemplateName(name: payload.name, context: context)

        let template = WorkoutTemplate(
            name: resolvedName,
            workoutType: payload.workoutType,
            durationMinutes: payload.durationMinutes,
            dateCreated: Date()
        )
        context.insert(template)

        for exercise in payload.exercises {
            let exerciseSet = TemplateExerciseSet(
                exerciseName: exercise.exerciseName,
                sets: exercise.sets,
                reps: exercise.reps,
                weightKg: exercise.weightKg,
                sortOrder: exercise.sortOrder
            )
            exerciseSet.template = template
            template.exerciseSets.append(exerciseSet)
        }

        try? context.save()
        return template
    }

    // MARK: - Duplicate Name Resolution

    /// Returns a unique template name, appending " (1)", " (2)", etc. if needed.
    static func resolveTemplateName(name: String, context: ModelContext) -> String {
        let descriptor = FetchDescriptor<WorkoutTemplate>()
        let existingTemplates = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existingTemplates.map(\.name))

        if !existingNames.contains(name) {
            return name
        }

        var counter = 1
        while true {
            let candidate = "\(name) (\(counter))"
            if !existingNames.contains(candidate) {
                return candidate
            }
            counter += 1
        }
    }
}
