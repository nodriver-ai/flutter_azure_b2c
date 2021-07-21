// Copyright © 2021 <Luca Calacci - Nodriver S.r.l>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the “Software”), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

package com.nodriver.flutter_azure_b2c

import android.content.Context
import androidx.annotation.NonNull
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.InputStreamReader
import java.io.Reader
import java.io.StringWriter
import java.io.Writer
import java.text.SimpleDateFormat
import java.util.*


val gson = Gson()

//convert a data class to a map
fun <T> T.serializeToMap(): Map<String, Any> {
    return convert()
}

//convert a map to a data class
inline fun <reified T> Map<String, Any>.toDataClass(): T {
    return convert()
}

//convert an object of type I to type O
inline fun <I, reified O> I.convert(): O {
    val json = gson.toJson(this)
    return gson.fromJson(json, object : TypeToken<O>() {}.type)
}

class PluginUtilities
{
    companion object {
        @JvmStatic
        fun getResourceFromContext(@NonNull context: Context, resName: String): String {
            val stringRes = context.resources.getIdentifier(resName, "string", context.packageName)
            if (stringRes == 0) {
                throw IllegalArgumentException(String.format("The 'R.string.%s' value it's not defined in your project's resources file.", resName))
            }
            return context.getString(stringRes)
        }

        @JvmStatic
        fun getRawResourceIdentifier(@NonNull context: Context, resName: String): Int {
            val res = context.resources.getIdentifier(resName, "raw", context.packageName)
            if (res == 0) {
                throw IllegalArgumentException(String.format("The 'R.string.%s' value it's not defined in your project's resources file.", resName))
            }
            return res;
        }

        @JvmStatic
        fun toIsoFormat(@NonNull date: Date): String {
            var outputFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
            return outputFormatter.format(date)
        }

        @JvmStatic
        fun readRawString(context: Context, configFileId: Int, encoding: String = "UTF-8"): String {
            var resource = context.resources.openRawResource(configFileId)
            val writer: Writer = StringWriter()
            val buffer = CharArray(1024)
            try {
                val reader: Reader = InputStreamReader(resource, encoding).buffered()
                var n: Int
                while (reader.read(buffer).also { n = it } != -1) {
                    writer.write(buffer, 0, n)
                }
            } finally {
                resource.close()
            }

            return writer.toString()
        }

    }
}