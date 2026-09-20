import SwiftUI
import WebKit
import AVKit

@main
struct DriveCastApp: App {
    @StateObject private var browser = BrowserStore()
    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(browser)
                .preferredColorScheme(.dark)
        }
    }
}

final class BrowserStore: NSObject, ObservableObject {
    @Published var address = "https://www.google.com"
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false

    let webView: WKWebView

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        load(address)
    }

    func load(_ value: String) {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.contains("://") {
            if text.contains(" ") {
                let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
                text = "https://www.google.com/search?q=\(q)"
            } else {
                text = "https://" + text
            }
        }
        guard let url = URL(string: text) else { return }
        address = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func back() { if webView.canGoBack { webView.goBack() } }
    func forward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }

    func updateState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        address = webView.url?.absoluteString ?? address
    }
}

extension BrowserStore: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) { updateState() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) { updateState() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) { updateState() }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var browser: BrowserStore
    func makeUIView(context: Context) -> WKWebView { browser.webView }
    func updateUIView(_ webView: WKWebView, context: Context) {}
}

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = .white
        picker.activeTintColor = .systemBlue
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct BrowserView: View {
    @EnvironmentObject private var browser: BrowserStore
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "car.fill").foregroundStyle(.blue)
                Text("DriveCast").font(.headline)
                Spacer()
                AirPlayButton().frame(width: 40, height: 40)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or enter website", text: $text)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit {
                        browser.load(text)
                        focused = false
                    }
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
            .padding(.horizontal)
            .padding(.vertical, 8)

            WebView(browser: browser)
                .overlay { if browser.isLoading { ProgressView() } }

            Divider()

            HStack {
                Button { browser.back() } label: { Image(systemName: "chevron.left") }
                    .disabled(!browser.canGoBack)
                Button { browser.forward() } label: { Image(systemName: "chevron.right") }
                    .disabled(!browser.canGoForward)
                Spacer()
                Button { browser.reload() } label: { Image(systemName: "arrow.clockwise") }
                Spacer()
                Button { browser.load("https://www.google.com") } label: { Image(systemName: "house") }
                Button { } label: { Image(systemName: "bookmark") }
            }
            .font(.title3)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .onAppear { text = browser.address }
        .onChange(of: browser.address) { _, value in
            if !focused { text = value }
        }
    }
}
