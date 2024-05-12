package org.zumi.strife30;

public class NativeLoader extends android.app.NativeActivity
{
    static
    {
        System.loadLibrary("main");
    }
}