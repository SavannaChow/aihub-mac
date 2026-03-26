package com.foss.aihub.ui.webview

import android.graphics.Bitmap
import android.util.Log
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import com.foss.aihub.MainActivity
import com.foss.aihub.models.AiService
import com.foss.aihub.utils.buildBlockedPage
import com.foss.aihub.utils.readAssetsFile
import java.io.ByteArrayInputStream

class ProgressTrackingWebViewClient(
    val context: MainActivity,
    private val onProgressUpdate: (Int) -> Unit,
    private val onLoadingStateChange: (Boolean) -> Unit,
    private val service: AiService,
    private val onError: (Int, String) -> Unit
) : WebViewClient() {
    private var hasErrorOccurred = false

    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        super.onPageStarted(view, url, favicon)
        hasErrorOccurred = false
        onLoadingStateChange(true)
        onProgressUpdate(0)
        Log.d("AI_HUB", "Page started: ${service.name} - $url")
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        super.onPageFinished(view, url)
        if (!hasErrorOccurred) {
            onProgressUpdate(100)
            onLoadingStateChange(false)

            if (view != null) {
                injectBlobInterceptor(view)
                injectShareInterceptor(view)
            }

            Log.d("AI_HUB", "Page finished: ${service.name} - $url")
        }
    }

    override fun onReceivedError(
        view: WebView?, request: WebResourceRequest?, error: WebResourceError?
    ) {
        super.onReceivedError(view, request, error)
        if (request?.isForMainFrame == true) {
            hasErrorOccurred = true
            onProgressUpdate(0)
            onLoadingStateChange(false)
            val errorCode = error?.errorCode ?: return
            val errorDescription = error.description?.toString() ?: "Unknown error"
            onError(errorCode, errorDescription)
            Log.e("WEBVIEW", "❌ Error loading ${service.name}: $errorCode - $errorDescription")
        }
    }

    override fun onReceivedHttpError(
        view: WebView?, request: WebResourceRequest?, errorResponse: WebResourceResponse?
    ) {
        super.onReceivedHttpError(view, request, errorResponse)
        // Ignoring server error
        if (errorResponse?.statusCode in 500..599) return
        if (request?.isForMainFrame == true) {
            hasErrorOccurred = true
            onProgressUpdate(0)
            onLoadingStateChange(false)
            val statusCode = errorResponse?.statusCode ?: return
            onError(errorResponse.statusCode, "HTTP Error $statusCode")
            Log.e("WEBVIEW", "❌ HTTP Error loading ${service.name}: $statusCode")
        }
    }

    override fun shouldInterceptRequest(
        view: WebView?, request: WebResourceRequest?,
    ): WebResourceResponse? {
        val url = request?.url?.toString() ?: return null
        if (!WebViewSecurity.allowConnectivityForService(service.id, url)) {
            Log.d("AI_HUB", "🚫 Blocked for ${service.name}: $url")
            return WebResourceResponse(
                "text/html",
                "UTF-8",
                ByteArrayInputStream(buildBlockedPage(context, url, service).toByteArray())
            )
        }
        return null
    }

    override fun shouldOverrideUrlLoading(
        view: WebView?, request: WebResourceRequest?
    ): Boolean {
        val service = view?.tag as? AiService ?: return false
        val url = request?.url?.toString() ?: return false

        if (!WebViewSecurity.allowConnectivityForService(service.id, url)) {
            Log.d("AI_HUB", "🚫 Navigation blocked for ${service.name}: $url")
            return true
        }

        Log.d("AI_HUB", "Loading in WebView: $url")
        return false
    }

    private fun injectBlobInterceptor(view: WebView) {
        val script = context.readAssetsFile("blobDownloadInterceptor.js").trimIndent()
        view.evaluateJavascript(script) { result ->
            Log.d("WebView", "Blob interceptor injection result: $result")
        }
    }

    private fun injectShareInterceptor(view: WebView) {
        val script = context.readAssetsFile("webSharePolyfill.js").trimIndent()
        view.evaluateJavascript(script) { result ->
            Log.d("WebView", "Share injection result: $result")
        }
    }
}