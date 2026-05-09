//
//  icepenguinApp.swift
//  icepenguin
//
//  Created by Whuttiphat Wiwatchaikul on 28/4/2569 BE.
//

import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import PDFKit

@main
struct IcePenguinApp: App {
    var body: some Scene {
        WindowGroup {
            IcePenguinView()
        }
    }
}

struct IcePenguinView: View {
    @State private var selectedImage: UIImage?
    @State private var history: [UIImage] = []
    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporterPresented = false
    @State private var importedURL: URL?
    
    // Gestures
    @State private var startPoint: CGPoint = .zero
    @State private var currentRect: CGRect = .zero
    @State private var isDragging = false
    
    // ขนาดพื้นที่แสดงรูปจริง
    @State private var editorSize: CGSize = .zero
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                if #available(iOS 16.0, *) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        retroButton("PHOTOS")
                    }
                } else {
                    Button(action: { /* Photos not available */ }) {
                        retroButton("PHOTOS")
                    }
                }
                Button(action: { isImporterPresented = true }) {
                    retroButton("FILES")
                }
                Spacer()
                Text("ICE PENGUIN v1.0")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .padding()
            
            Divider().background(Color.black)

            // Editor Area
            GeometryReader { geo in
                ZStack {
                    Color(white: 0.95).ignoresSafeArea()
                    
                    if let img = selectedImage {
                        editorLayer(for: img, in: geo.size)
                    } else {
                        if #available(iOS 17.0, *) {
                            ContentUnavailableView("No Media", systemImage: "photo.badge.plus", description: Text("Select an image to start redacting pixels."))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus").font(.largeTitle)
                                Text("No Media").font(.headline)
                                Text("Select an image to start redacting pixels.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    }
                }
            }

            Divider().background(Color.black)

            // Bottom Bar
            HStack(spacing: 15) {
                Button(action: applyRedaction) {
                    retroButton("REDACT", color: .black, textColor: .white)
                }
                .disabled(currentRect.isEmpty)
                
                Button(action: undo) {
                    retroButton("UNDO")
                }
                .disabled(history.isEmpty)
                
                Spacer()
                
                Button(action: exportImage) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.black)
                }
            }
            .padding()
        }
        .navigationTitle("IcePenguin")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, _ in loadPhoto() }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [UTType.image, UTType.pdf]) { result in
            switch result {
            case .success(let url):
                importedURL = url
                loadFromURL(url)
            case .failure:
                break
            }
        }
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                mainContent
            }
        } else {
            NavigationView {
                mainContent
                    .navigationBarTitle("IcePenguin", displayMode: .inline)
            }
        }
    }
}

// MARK: - Logic & Pixel Processing
extension IcePenguinView {
    
    private func updateRect(with location: CGPoint, in size: CGSize) {
        let x = max(0, min(startPoint.x, location.x))
        let y = max(0, min(startPoint.y, location.y))
        let w = min(abs(location.x - startPoint.x), size.width - x)
        let h = min(abs(location.y - startPoint.y), size.height - y)
        currentRect = CGRect(x: x, y: y, width: w, height: h)
    }
    
    @ViewBuilder
    private func editorLayer(for img: UIImage, in containerSize: CGSize) -> some View {
        let frame = displayedFrame(imageSize: img.size, containerSize: containerSize)
        let displayedSize = frame.size
        let origin = frame.origin

        ZStack {
            Image(uiImage: img)
                .resizable()
                .frame(width: displayedSize.width, height: displayedSize.height)
                .position(x: origin.x + displayedSize.width/2, y: origin.y + displayedSize.height/2)

            ZStack(alignment: .topLeading) {
                if isDragging || !currentRect.isEmpty {
                    Rectangle()
                        .stroke(Color.red, lineWidth: 2)
                        .background(Color.black.opacity(0.3))
                        .frame(width: currentRect.width, height: currentRect.height)
                        .offset(x: origin.x + currentRect.minX, y: origin.y + currentRect.minY)
                }
            }
        }
        .contentShape(Rectangle())
        .onAppear { editorSize = displayedSize }
        .onChange(of: displayedSize) { editorSize = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    let location = CGPoint(x: val.location.x - origin.x, y: val.location.y - origin.y)
                    let clamped = CGPoint(x: max(0, min(location.x, displayedSize.width)),
                                          y: max(0, min(location.y, displayedSize.height)))
                    if !isDragging {
                        startPoint = clamped
                        isDragging = true
                    }
                    updateRect(with: clamped, in: displayedSize)
                }
                .onEnded { _ in isDragging = false }
        )
    }

    private func applyRedaction() {
        guard let img = selectedImage else { return }
        
        let renderer = UIGraphicsImageRenderer(size: img.size)
        let newImage = renderer.image { ctx in
            img.draw(at: .zero)
            let pixelRect = calculatePixelRect(from: currentRect,
                                               imageSize: img.size,
                                               viewSize: editorSize)
            let clippedRect = CGRect(x: max(0, pixelRect.origin.x),
                                     y: max(0, pixelRect.origin.y),
                                     width: max(0, min(pixelRect.size.width, img.size.width - max(0, pixelRect.origin.x))),
                                     height: max(0, min(pixelRect.size.height, img.size.height - max(0, pixelRect.origin.y))))
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(clippedRect)
        }
        
        history.append(img)
        if history.count > 10 { history.removeFirst() } // จำกัด history
        
        selectedImage = newImage
        currentRect = .zero
    }
    
    private func calculatePixelRect(from rect: CGRect,
                                    imageSize: CGSize,
                                    viewSize: CGSize) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var scale: CGFloat
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0
        
        if imageAspect > viewAspect {
            scale = imageSize.width / viewSize.width
            let fittedHeight = imageSize.height / scale
            yOffset = (viewSize.height - fittedHeight) / 2
        } else {
            scale = imageSize.height / viewSize.height
            let fittedWidth = imageSize.width / scale
            xOffset = (viewSize.width - fittedWidth) / 2
        }
        
        let x = (rect.minX - xOffset) * scale
        let y = (rect.minY - yOffset) * scale
        let w = rect.width * scale
        let h = rect.height * scale
        
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    private func displayedFrame(imageSize: CGSize, containerSize: CGSize) -> (size: CGSize, origin: CGPoint) {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = containerSize.width / containerSize.height
        if imageAspect > viewAspect {
            let width = containerSize.width
            let height = width / imageAspect
            let origin = CGPoint(x: 0, y: (containerSize.height - height) / 2)
            return (CGSize(width: width, height: height), origin)
        } else {
            let height = containerSize.height
            let width = height * imageAspect
            let origin = CGPoint(x: (containerSize.width - width) / 2, y: 0)
            return (CGSize(width: width, height: height), origin)
        }
    }

    private func loadPhoto() {
        Task {
            if let data = try? await pickerItem?.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                await MainActor.run {
                    let clean = ui.pngData().flatMap { UIImage(data: $0) } ?? ui
                    selectedImage = clean
                    history = []
                    currentRect = .zero
                }
            }
        }
    }
    
    private func contentType(for url: URL) -> UTType? {
        if let typeId = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
           let type = UTType(typeId) {
            return type
        }
        let ext = url.pathExtension
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            return type
        }
        return nil
    }
    
    private func loadFromURL(_ url: URL) {
        if let type = contentType(for: url) {
            if type.conforms(to: .image) {
                if let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
                    // Re-encode to strip metadata
                    let clean = ui.pngData().flatMap { UIImage(data: $0) } ?? ui
                    selectedImage = clean
                    history = []
                    currentRect = .zero
                }
                return
            }
            if type.conforms(to: .pdf) {
                if let doc = PDFDocument(url: url), let page = doc.page(at: 0) {
                    let pageRect = page.bounds(for: .mediaBox)
                    let scale: CGFloat = 2.0
                    let size = CGSize(width: pageRect.size.width * scale, height: pageRect.size.height * scale)
                    let renderer = UIGraphicsImageRenderer(size: size)
                    let img = renderer.image { ctx in
                        UIColor.white.setFill()
                        ctx.fill(CGRect(origin: .zero, size: size))
                        ctx.cgContext.saveGState()
                        ctx.cgContext.translateBy(x: 0, y: size.height)
                        ctx.cgContext.scaleBy(x: scale, y: -scale)
                        page.draw(with: .mediaBox, to: ctx.cgContext)
                        ctx.cgContext.restoreGState()
                    }
                    selectedImage = img
                    history = []
                    currentRect = .zero
                }
                return
            }
        }
        // Fallback: try image decode
        if let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
            let clean = ui.pngData().flatMap { UIImage(data: $0) } ?? ui
            selectedImage = clean
            history = []
            currentRect = .zero
        }
    }
    
    private func undo() {
        if let last = history.popLast() {
            selectedImage = last
        }
    }
    
    private func exportImage() {
        guard let img = selectedImage else { return }
        // Strip metadata by re-encoding
        guard let data = img.pngData() else { return }
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("IcePenguin-Redacted.png")
        try? FileManager.default.removeItem(at: tmpURL)
        do { try data.write(to: tmpURL) } catch { return }
        let av = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}

// MARK: - Components
extension IcePenguinView {
    func retroButton(_ title: String, color: Color = .white, textColor: Color = .black) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(color)
            .border(Color.black, width: 2)
            .foregroundColor(textColor)
    }
}

