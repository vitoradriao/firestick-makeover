package io.github.vitoradriao.makeover;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.view.ViewTreeObserver;

// Makeover as an app: the Home screen in a window of its own. See HomeScreen for everything else.
public class MainActivity extends Activity {
    static final String HOME = "home"; // extra: opened by the Home button, so go back to the dock
    HomeScreen screen;
    boolean home;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        screen = new HomeScreen(this);
        screen.applyExtras(getIntent());
        setContentView(screen);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        home = intent.getBooleanExtra(HOME, false);
        screen.applyExtras(intent);
    }

    @Override
    protected void onResume() {
        super.onResume();
        HomeService.pausedUntil = 0;
        screen.onShown(home);
        home = false;
        // Once this has drawn, the overlay covering Amazon's launcher can step aside. Not sooner, or
        // Amazon's launcher shows through for a moment.
        screen.getViewTreeObserver().addOnPreDrawListener(new ViewTreeObserver.OnPreDrawListener() {
            @Override public boolean onPreDraw() {
                screen.getViewTreeObserver().removeOnPreDrawListener(this);
                screen.postDelayed(HomeService::appShown, 150);
                return true;
            }
        });
    }

    // Fire TV starts on Amazon's home screen; this opens Makeover as soon as the TV has booted, or Makeover has updated.
    public static class Boot extends BroadcastReceiver {
        @Override
        public void onReceive(Context c, Intent i) {
            c.startActivity(new Intent(c, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
    }
}
