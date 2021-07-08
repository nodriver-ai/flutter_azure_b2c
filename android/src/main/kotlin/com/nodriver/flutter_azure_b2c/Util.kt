package com.nodriver.flutter_azure_b2c

import android.content.Context
import androidx.annotation.NonNull
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
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
            return outputFormatter.format(date);
        }

    }
}