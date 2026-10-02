package de.icd360sev.schatzmeister

import android.app.Activity
import android.app.Application
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.WeakHashMap

/**
 * Die Zwischenablage der App: was die App hineinlegt, ist nach höchstens
 * [FRIST_MS] wieder weg -- und die App sagt es.
 *
 * Wie in der Vorsitzer-App (dort #1045 und #1049, 02.10.2026). Festlegung des
 * Vorsitzenden: „cand copiem ceva indiferent ce este sa fie 30 de secunde
 * timerul si sa stearga tot clipboard", auch „unde exista cu click dreapta",
 * und dieselbe Absicherung hier ("Aceeași protecție în mitglieder și
 * schatzmeister").
 *
 * WARUM: Android hebt Kopiertes auf, lange nachdem die App es vergessen hat.
 * Die Zwischenablage selbst leert erst Android 13+ nach einer Stunde. Die
 * Tastaturen führen einen eigenen Verlauf: Gboard eine Stunde (Angeheftetes
 * für immer), Samsung ohne Frist und unverschlüsselt (heise, April 2025).
 *
 * Wie:
 * - JEDE Kopie aus Dart kommt über [KANAL]: die Kopier-Knöpfe und „Kopieren"
 *   im Kontextmenü (Rechtsklick, langes Drücken) jedes Textfelds. Dafür fängt
 *   `SicherClipboardBindung` (lib/utils/sicher_clipboard_bindung.dart)
 *   Flutters `Clipboard.setData` ab.
 * - SENSIBEL markiert (`EXTRA_IS_SENSITIVE`): Tastatur und System-Vorschau
 *   zeigen Punkte statt des Werts. Samsungs Verlauf liest das nicht; dagegen
 *   hilft nur die kurze Frist.
 * - Was Dart nicht sieht (Text im WebView markiert und kopiert, die
 *   Kopier-Knöpfe einer Seite), meldet Android selbst ([beobachten]) --
 *   solange die App vorn ist. [nachmarkieren] legt es gleich danach als
 *   sensibel neu ab.
 * - Gelöscht wird in zwei Schritten, wie bei Bitwarden (android PR 7169,
 *   gemergt am 21.09.2026): erst ein leerer, sensibler Clip darüber, dann
 *   `clearPrimaryClip()`. Das Löschen allein blieb dort auf Android 13 bis 16
 *   wirkungslos, auch mit Gboard.
 * - Auch im Hintergrund: Android 10+ sperrt für Apps im Hintergrund nur das
 *   LESEN der Zwischenablage, nicht das Schreiben.
 *
 * WARNUNG Im Hintergrund sieht die App nicht, was gerade in der
 * Zwischenablage liegt. Kopiert man in den 30 Sekunden in einer ANDEREN App
 * etwas, ist das danach auch weg -- „sa stearga tot clipboard".
 *
 * WARNUNG Der Zeitgeber lebt im Prozess, nicht in Dart: ein Dart-Timer stünde
 * still, solange Android die Engine anhält, und ginge mit ihr unter.
 */
internal object Zwischenablage {
    const val KANAL = "de.icd360sev.schatzmeister/clipboard"

    /** Länger bleibt nichts aus der App in der Zwischenablage. */
    const val FRIST_MS = 30_000L

    private const val TAG = "Zwischenablage"

    /** Steht in jedem Clip, den diese Klasse legt -- [beobachten] lässt ihn aus. */
    private const val EIGEN = "de.icd360sev.schatzmeister.zwischenablage"

    private val haupt = Handler(Looper.getMainLooper())
    private var app: Context? = null
    private var beobachter: ClipboardManager.OnPrimaryClipChangedListener? = null

    /** Liegt noch etwas aus der App in der Zwischenablage? */
    private var faellig = false

    /** Die Fenster der App, die eine Löschung anzeigen: wann, und ob verspätet. */
    private val fenster = WeakHashMap<Activity, (Long, Boolean) -> Unit>()

    /** Die Fenster, die gerade vorn sind, mit dem Augenblick, in dem sie es wurden. */
    private val vorn = WeakHashMap<Activity, Long>()

    /** Eine Löschung, die noch kein Fenster gezeigt hat (Millisekunden seit 1970). */
    private var offen: Long? = null

    private val loeschen = Runnable { leeren() }

    /**
     * Das Flutter-Fenster: [KANAL] für seine Engine, und die Löschung wird in
     * ihm angezeigt (lib/utils/zwischenablage_hinweis.dart). Aus
     * `configureFlutterEngine`.
     */
    fun anbinden(a: Activity, engine: FlutterEngine) {
        val kanal = MethodChannel(engine.dartExecutor.binaryMessenger, KANAL)
        kanal.setMethodCallHandler { call, result ->
            when (call.method) {
                "copySensitive" -> result.success(
                    kopieren(
                        a,
                        call.argument<String>("text") ?: "",
                        call.argument<Number>("frist")?.toLong() ?: FRIST_MS
                    )
                )
                "leere" -> {
                    leeren()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        anmelden(a) { zeit, spaet ->
            kanal.invokeMethod("geloescht", mapOf("zeit" to zeit, "spaet" to spaet))
        }
    }

    /**
     * Ein Fenster der App, das eine Löschung anzeigen kann. Aus `onCreate`
     * (bzw. `configureFlutterEngine`), damit sein erstes `onResume` schon
     * mitzählt.
     */
    fun anmelden(a: Activity, zeigen: (zeit: Long, spaet: Boolean) -> Unit) {
        beobachten(a)
        if (fenster.put(a, zeigen) != null) return
        // ⚠️ Über die Application, nicht `a.registerActivityLifecycleCallbacks`:
        // das gibt es erst ab Android 10, und minSdk ist hier 24.
        a.application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) {
                if (activity !== a) return
                vorn[activity] = SystemClock.uptimeMillis()
                // Gelöscht, während man woanders war: jetzt nachholen.
                val zeit = offen ?: return
                offen = null
                fenster[activity]?.invoke(zeit, true)
            }

            override fun onActivityPaused(activity: Activity) {
                if (activity === a) vorn.remove(activity)
            }

            override fun onActivityDestroyed(activity: Activity) {
                if (activity !== a) return
                vorn.remove(activity)
                fenster.remove(activity)
                activity.application.unregisterActivityLifecycleCallbacks(this)
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
        })
    }

    /**
     * Legt [text] sensibel in die Zwischenablage und löscht ihn nach [frist],
     * höchstens nach [FRIST_MS]. Leerer Text heißt: jetzt leeren.
     */
    fun kopieren(ctx: Context, text: String, frist: Long = FRIST_MS): Boolean {
        if (text.isEmpty()) {
            leeren()
            return true
        }
        beobachten(ctx)
        val cm = ablage(ctx) ?: return false
        return try {
            cm.setPrimaryClip(ClipData.newPlainText("", text).also { it.description.extras = sensibel() })
            planen(frist)
            true
        } catch (e: Exception) {
            Log.w(TAG, "kopieren: ${e.javaClass.simpleName}")
            false
        }
    }

    /**
     * Leert die Zwischenablage jetzt -- nur, wenn noch etwas aus der App darin
     * liegt: was danach in einer anderen App kopiert wurde, bleibt sonst stehen.
     */
    fun leeren() {
        haupt.removeCallbacks(loeschen)
        if (!faellig) return
        faellig = false
        val cm = app?.let { ablage(it) } ?: return
        try {
            // 1. Darüber ein leerer, sensibler Clip: was die Tastatur als
            //    „zuletzt kopiert" anbietet, ist danach nichts mehr.
            cm.setPrimaryClip(ClipData.newPlainText("", "").also { it.description.extras = sensibel() })
            // 2. Und ganz weg -- `clearPrimaryClip` gibt es erst ab Android 9;
            //    davor bleibt der leere Clip.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) cm.clearPrimaryClip()
        } catch (e: Exception) {
            Log.w(TAG, "leeren: ${e.javaClass.simpleName}")
            return
        }
        melden(System.currentTimeMillis())
    }

    private fun planen(frist: Long) {
        faellig = true
        haupt.removeCallbacks(loeschen)
        haupt.postDelayed(loeschen, frist.coerceIn(1_000L, FRIST_MS))
    }

    /**
     * Zeigt die Löschung in dem Fenster, in dem man gerade ist: dem mit dem
     * Fokus, sonst dem, das zuletzt nach vorn kam. Ist keins vorn, im nächsten.
     */
    private fun melden(zeit: Long) {
        val ziel = vorn.keys.filter { fenster.containsKey(it) }
            .maxWithOrNull(compareBy<Activity>({ it.hasWindowFocus() }, { vorn[it] ?: 0L }))
        if (ziel == null) {
            offen = zeit
            return
        }
        offen = null
        fenster[ziel]?.invoke(zeit, false)
    }

    /**
     * Was Dart nicht sieht, meldet Android: jede neue Kopie, solange die App
     * vorn ist. Einmal je Prozess.
     */
    private fun beobachten(ctx: Context) {
        if (beobachter != null) return
        val a = ctx.applicationContext
        app = a
        val cm = ablage(a) ?: return
        val b = ClipboardManager.OnPrimaryClipChangedListener {
            // ⚠️ Nur, wenn die App vorn ist. Ab Android 10 meldet das System
            // ohnehin nur ihr; davor (minSdk 24) auch jede Kopie anderer Apps,
            // während sie im Hintergrund läuft -- die gehen sie nichts an.
            if (vorn.isEmpty()) return@OnPrimaryClipChangedListener
            // Erst nur die Beschreibung. Null heißt: geleert oder nicht lesbar.
            val d = try {
                cm.primaryClipDescription
            } catch (_: Exception) {
                null
            } ?: return@OnPrimaryClipChangedListener
            // Selbst gelegt: das plant [kopieren] schon, mit seiner Frist.
            if (d.extras?.getBoolean(EIGEN) == true) return@OnPrimaryClipChangedListener
            nachmarkieren(cm)
            planen(FRIST_MS)
        }
        cm.addPrimaryClipChangedListener(b)
        beobachter = b
    }

    /**
     * Ein Clip ohne Markierung -- die WebViews, die Kopier-Knöpfe einer Seite,
     * Ausschneiden: noch einmal, als SENSIBEL. Die Tastatur hat ihn dann für
     * einen Augenblick im Klartext gesehen; was sie danach als „zuletzt
     * kopiert" anbietet, zeigt Punkte.
     *
     * WARNUNG Den Inhalt zu lesen meldet Android 12+ als „… hat aus der
     * Zwischenablage eingefügt" -- aber nur, wenn er aus einer ANDEREN App
     * stammt. Was Android meldet, während die App vorn ist, kommt praktisch
     * immer aus der App selbst; kommt es doch von außen (Kopie über Geräte
     * hinweg), erscheint die Meldung einmal.
     *
     * Nur Text: ein Bild oder eine Datei hängt an einer Freigabe, die dieser
     * Clip nicht weitergeben dürfte -- das bleibt, wie es ist, und wird nach
     * 30 s trotzdem gelöscht.
     */
    private fun nachmarkieren(cm: ClipboardManager) {
        try {
            val alt = cm.primaryClip ?: return
            val stuecke = (0 until alt.itemCount).map { alt.getItemAt(it) }
            if (stuecke.isEmpty() || stuecke.any { it.text == null || it.uri != null || it.intent != null }) return
            val d = alt.description
            val neu = ClipData(
                ClipDescription(d.label, Array(d.mimeTypeCount) { d.getMimeType(it) })
                    .also { it.extras = sensibel() },
                ClipData.Item(stuecke[0].text, stuecke[0].htmlText)
            )
            for (s in stuecke.drop(1)) neu.addItem(ClipData.Item(s.text, s.htmlText))
            cm.setPrimaryClip(neu)
        } catch (e: Exception) {
            Log.w(TAG, "nachmarkieren: ${e.javaClass.simpleName}")
        }
    }

    private fun ablage(ctx: Context): ClipboardManager? =
        ctx.getSystemService(ClipboardManager::class.java)

    /** Sensibel (ab Android 13 die Konstante, davor derselbe Schlüssel als Text) und als eigen markiert. */
    private fun sensibel() = PersistableBundle().apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
        } else {
            putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        putBoolean(EIGEN, true)
    }
}
