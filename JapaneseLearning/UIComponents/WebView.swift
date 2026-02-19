//
//  WebView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 8/01/14.
//

import SwiftUI
import WebKit

enum SiteRule {
    static let Netflix = """
        (function () {
            const remove = (selector) => {
                document.querySelectorAll(selector).forEach(e => e.remove());
            };

            const observer = new MutationObserver(() => {
                remove('header');
                remove('[data-uia="jump-links"]');
                remove('form + div');
                remove('form');
                remove('header + div');
                remove('[data-uia="floating-cta"]');
            });
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })();
    """
    static let Hulu = """
        (function () {
            const remove = (selector) => {
                document.querySelectorAll(selector).forEach(e => e.remove());
            };

            const observer = new MutationObserver(() => {
                remove('.start-recomended');
                remove('.share-wrapper');
                remove('header');
                remove('.sp-nav-footer');
            });
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })();
    """
    static let ABEMA = """
        (function () {
            const remove = (selector) => {
                document.querySelectorAll(selector).forEach(e => e.remove());
            };

            const observer = new MutationObserver(() => {
                remove('.com-pages-series-MobileSeriesSection__view-app-button');
                remove('header');
                remove('.c-application-MobileAppContainer__floating-app-button');
    
                let button = document.querySelector("button.com-m-FadedExpandableBlock__button")
                if (button) button.click()
    
                const style = document.createElement('style');
                style.innerHTML = `
                    .com-pages-series-MobileSeriesSection__card-image::after {
                        display: none !important;
                        content: none !important;
                    }
                `;
                document.head.appendChild(style);
            });
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })();
    """
    static let UNEXT = """
        (function () {
            const remove = (selector) => {
                document.querySelectorAll(selector).forEach(e => e.remove());
            };

            const observer = new MutationObserver(() => {
                remove('[data-testid="titleModal-header-close-btn"]');
    
                const paymentBadge = document.querySelector(
                    'div[data-testid="paymentBadge"]'
                );
                if (paymentBadge) {
                    const paymentBadge_wrapperDiv = paymentBadge.closest('div');
                    if (paymentBadge_wrapperDiv) paymentBadge_wrapperDiv.remove();
                }
    
                const signup = document.querySelector(
                    'a[data-testid="videoDetail-stage-signup"]'
                );
                if (signup) {
                    const signup_wrapperDiv = signup.closest('div');
                    if (signup_wrapperDiv) signup_wrapperDiv.remove();
                }

                const mylist = document.querySelector(
                    'button[data-testid="videoMainSection-stage-mylist"]'
                );
                if (mylist) {
                    const parent = mylist.parentElement;
                    const grandParent = parent?.parentElement;
                    if (grandParent && grandParent.tagName === 'DIV') {
                        grandParent.remove();
                    }
                }
            });
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })();
    """
    static let THEMOVIE = """
        (function () {
            const remove = (selector) => {
                document.querySelectorAll(selector).forEach(e => e.remove());
            };

            const observer = new MutationObserver(() => {
                remove('ul.auto.actions');
                remove('#shortcut_bar_scroller');
                remove('header');
                document.querySelector("#main").style.margin = "0px";
                remove(".genre_wrapper");
                remove("ol.people.no_image");
                remove("div.white_column > div");
            });
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })();
    """
    static let AppleTV = """
        (function () {
            const observer = new MutationObserver(() => {
                let header = document.querySelector('[data-testid="header"]');
                if (header) header.remove();

                const spans = document.querySelectorAll(
                    'h2[data-testid="header-title"] span'
                );
                spans.forEach(span => {
                    if (span.textContent?.trim() === '関連') {
                        const section = span.closest(
                            'div[data-testid="section-container"]'
                        );
                        if (section) {
                            section.remove();
                        }
                    }
                });

                document.querySelector('p[data-testid="truncate-text"]').style.setProperty('--lines', '4');
            });
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })();
    """
    static let FOD = """
        (function () {
            const remove = (selector) => {
                document.querySelectorAll(selector).forEach(e => e.remove());
            };

            const observer = new MutationObserver(() => {
                remove('header');
                remove('.ps-scroll_box');
                remove('.st-Contents > .sp-only');
                remove('div.geGePr-Tags');
                remove('button.sw-Fav-mylist');
                remove('button.sw-Good2-off-title');
                remove('a.sw-Share-title');
                document.querySelector(".st-Contents").style.paddingTop = "0px";
                document.querySelector(".geGePr-MV").style.marginBottom = "0px";
                window.scrollTo(0, 0);
            });
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })();
    """
    static let Others = """
        (function () {
            const header = document.querySelector("header") || document.querySelector(".header");
            if (header) {
                header.style.position = "absolute";
                header.style.top = "0";
            }
        })();
    """
}

struct WebView: UIViewRepresentable {

    let url: URL
    @Binding var isLoading: Bool

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {

        let config = WKWebViewConfiguration()

        if let host = url.host {
            let js = jsForHost(host)
            if let js {
                let userScript = WKUserScript(
                    source: js,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
                config.userContentController.addUserScript(userScript)
            }
        }

        let webView = WKWebView(frame: .zero, configuration: config)

        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func jsForHost(_ host: String) -> String? {

        if host.contains("netflix.com") {
            return SiteRule.Netflix
        }

        if host.contains("hulu.jp") {
            return SiteRule.Hulu
        }

        if host.contains("abema.tv") {
            return SiteRule.ABEMA
        }

        if host.contains("video.unext.jp") {
            return SiteRule.UNEXT
        }

        if host.contains("themoviedb.org") {
            return SiteRule.THEMOVIE
        }

        if host.contains("tv.apple.com") {
            return SiteRule.AppleTV
        }

        if host.contains("fod.fujitv.co") {
            return SiteRule.FOD
        }

        return SiteRule.Others
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
    }
}
