/*---------------------------------------------------------------------------------------------
* Copyright (c) Bentley Systems, Incorporated. All rights reserved.
* See LICENSE.md in the project root for license terms and full copyright notice.
*--------------------------------------------------------------------------------------------*/
package com.bentley.sample.camera

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.appcompat.app.AppCompatActivity
import com.eclipsesource.json.Json
import com.eclipsesource.json.JsonValue
import com.github.itwin.mobilesdk.ITMNativeUI
import com.github.itwin.mobilesdk.ITMNativeUIComponent
import kotlin.coroutines.Continuation
import kotlin.coroutines.suspendCoroutine

object ImagePickerConstants {
    const val urlScheme = "com.bentley.itms-image-cache"
}

private class PickIModelImageContract(private val context: ContextWrapper?): PickUriContract("images", context, ImagePickerConstants.urlScheme) {
    override fun createIntent(context: Context, input: JsonValue?): Intent {
        val obj = input?.asObject()
        if (obj != null) {
            destDir = "images/${obj.getString("iModelId", "unknownModelId")}"
            // TODO: handle sourceType
        }
        return super.createIntent(context, input)
            .setAction(Intent.ACTION_PICK)
            .setType("image/*")
    }
}

class ImagePicker(nativeUI: ITMNativeUI): ITMNativeUIComponent(nativeUI) {
    init {
        listener = coMessenger.addQueryListener("pickImage", ::handleQuery)
    }

    companion object {
        private var startForResult: ActivityResultLauncher<JsonValue?>? = null
        private var activeContinuation: Continuation<JsonValue?>? = null

        fun registerForActivityResult(activity: AppCompatActivity) {
            startForResult = activity.registerForActivityResult(PickIModelImageContract(activity)) { uri ->
                activeContinuation?.resumeWith(Result.success(Json.value(uri?.toString() ?: "")))
                activeContinuation = null
            }
        }
    }

    private suspend fun handleQuery(params: JsonValue?): JsonValue? {
        return suspendCoroutine { continuation ->
            activeContinuation = continuation
            startForResult?.launch(params)
        }
    }
}