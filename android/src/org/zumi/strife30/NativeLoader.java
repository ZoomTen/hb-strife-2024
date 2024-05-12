package org.zumi.strife30;
import android.os.Bundle;
import android.view.View;

public class NativeLoader extends android.app.NativeActivity
{
    static
    {
        System.loadLibrary("main");
    }

    @Override
    protected void onCreate(Bundle saved)
    {
        super.onCreate(saved);
        View decorView = getWindow().getDecorView();
        decorView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION);
    }
}