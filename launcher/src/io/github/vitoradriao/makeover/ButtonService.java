package io.github.vitoradriao.makeover;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Remote app buttons (Prime Video, Peacock...) open the app you choose instead.
 *
 * Fire OS launches those buttons with ActivityTaskManager "START" log lines that name the button
 * ("deeplink_prime_video", "asin=..."). This service reads the log (READ_LOGS, granted over adb by
 * makeover.ps1) and opens the chosen app on top. Being an accessibility service keeps it running and
 * lets it start activities from the background.
 *
 * Rules live in the "remap" preference: "text in the button's log line>package;...", set by
 * makeover.ps1 through MainActivity's --es remap extra. Empty means nothing is remapped.
 */
public class ButtonService extends AccessibilityService {
    static final String RULES = "remap";
    private static final String TAG = "makeover-remap";
    // Screens Amazon opens a moment after the button press; covering them again keeps our app on top.
    private static final String[] FOLLOW_UPS = {"com.amazon.venezia/.details", "com.amazon.firebat/"};
    private static final long FOLLOW_UP_MS = 5000;

    private final Handler main = new Handler(Looper.getMainLooper());
    private volatile boolean running;
    private volatile Process logcat;

    @Override
    protected void onServiceConnected() {
        if (running) return;
        running = true;
        Thread t = new Thread(this::watch, "makeover-remap");
        t.setDaemon(true);
        t.start();
    }

    private void watch() {
        while (running) {
            // Start at "now" so a restart never replays an old button press.
            String since = new SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US).format(new Date());
            try {
                Process p = Runtime.getRuntime().exec(
                        new String[] {"logcat", "-v", "time", "-T", since, "-s", "ActivityTaskManager:I"});
                logcat = p;
                BufferedReader in = new BufferedReader(new InputStreamReader(p.getInputStream()));
                String pending = null;
                long until = 0;
                String line;
                while (running && (line = in.readLine()) != null) {
                    if (!line.contains("START u0")) continue;
                    String target = match(line);
                    if (target != null) {
                        pending = target;
                        until = SystemClock.uptimeMillis() + FOLLOW_UP_MS;
                        open(target);
                    } else if (pending != null && SystemClock.uptimeMillis() < until && isFollowUp(line)) {
                        open(pending);
                    }
                }
                p.destroy();
            } catch (Exception e) {
                Log.w(TAG, "logcat parou", e);
            }
            SystemClock.sleep(1000);
        }
    }

    // Rules are read on each app start, so a change from makeover.ps1 applies right away.
    private String match(String line) {
        String spec = getSharedPreferences("makeover", Context.MODE_PRIVATE).getString(RULES, "");
        for (String rule : spec.split(";")) {
            int sep = rule.indexOf('>');
            if (sep > 0 && line.contains(rule.substring(0, sep).trim())) return rule.substring(sep + 1).trim();
        }
        return null;
    }

    private static boolean isFollowUp(String line) {
        for (String f : FOLLOW_UPS) {
            if (line.contains(f)) return true;
        }
        return false;
    }

    private void open(String pkg) {
        main.post(() -> {
            PackageManager pm = getPackageManager();
            Intent launch = pm.getLeanbackLaunchIntentForPackage(pkg);
            if (launch == null) launch = pm.getLaunchIntentForPackage(pkg);
            if (launch == null) {
                Log.w(TAG, "app nao instalado: " + pkg);
                return;
            }
            try {
                startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED));
                Log.i(TAG, "abriu " + pkg);
            } catch (Exception e) {
                Log.w(TAG, "falha ao abrir " + pkg, e);
            }
        });
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {}

    @Override
    public void onInterrupt() {}

    @Override
    public void onDestroy() {
        running = false;
        Process p = logcat;
        if (p != null) p.destroy();
        super.onDestroy();
    }
}
