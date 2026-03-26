package com.foss.aihub.utils

import android.content.Context
import java.io.BufferedReader
import java.io.InputStreamReader

fun Context.readAssetsFile(fileName: String): String {
    return try {
        val inputStream = assets.open(fileName)
        val reader = BufferedReader(InputStreamReader(inputStream))
        val stringBuilder = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            stringBuilder.append(line).append("\n")
        }
        reader.close()
        stringBuilder.toString()
    } catch (e: Exception) {
        e.printStackTrace()
        ""
    }
}