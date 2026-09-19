package com.arthatrack.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Lightweight, zero-dependency native SQLite helper for ephemeral notification persistence.
 *
 * Guarantees At-Least-Once Delivery: Every bank and UPI push notification intercepted
 * by NotificationListener is immediately written to disk before dispatching to Flutter.
 * Even if the process dies, the phone reboots, or Flutter is killed, pending notifications
 * remain safely on disk until Flutter drains and acknowledges them.
 */
class NotificationDbHelper private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "arthatrack_notifications.db"
        private const val DATABASE_VERSION = 1

        const val TABLE_NAME = "notification_journal"
        const val COL_ID = "id"
        const val COL_PACKAGE_NAME = "package_name"
        const val COL_TITLE = "title"
        const val COL_TEXT = "text"
        const val COL_BIG_TEXT = "big_text"
        const val COL_SUB_TEXT = "sub_text"
        const val COL_POST_TIME = "post_time"
        const val COL_PROCESSED = "processed"
        const val COL_CREATED_AT = "created_at"

        @Volatile
        private var instance: NotificationDbHelper? = null

        fun getInstance(context: Context): NotificationDbHelper {
            return instance ?: synchronized(this) {
                instance ?: NotificationDbHelper(context).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTableQuery = """
            CREATE TABLE IF NOT EXISTS $TABLE_NAME (
                $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_PACKAGE_NAME TEXT NOT NULL,
                $COL_TITLE TEXT,
                $COL_TEXT TEXT,
                $COL_BIG_TEXT TEXT,
                $COL_SUB_TEXT TEXT,
                $COL_POST_TIME INTEGER,
                $COL_PROCESSED INTEGER DEFAULT 0,
                $COL_CREATED_AT INTEGER
            )
        """.trimIndent()
        db.execSQL(createTableQuery)

        db.execSQL("CREATE INDEX IF NOT EXISTS idx_pending ON $TABLE_NAME ($COL_PROCESSED, $COL_POST_TIME)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_dup ON $TABLE_NAME ($COL_PACKAGE_NAME, $COL_POST_TIME)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Migration logic if schema changes in future versions
    }

    @Synchronized
    fun insertNotification(payload: Map<String, Any?>): Long {
        return try {
            val db = writableDatabase
            val pkgName = payload["packageName"] as? String ?: ""
            val title = payload["title"] as? String ?: ""
            val text = payload["text"] as? String ?: ""
            val bigText = payload["bigText"] as? String ?: ""
            val subText = payload["subText"] as? String ?: ""
            val postTime = (payload["postTime"] as? Number)?.toLong() ?: System.currentTimeMillis()

            // Fast native deduplication: check if exact notification was recorded within the last 10 minutes
            val tenMinutesAgo = postTime - (10 * 60 * 1000)
            val cursor = db.query(
                TABLE_NAME,
                arrayOf(COL_ID),
                "$COL_PACKAGE_NAME = ? AND $COL_TEXT = ? AND $COL_POST_TIME >= ?",
                arrayOf(pkgName, text, tenMinutesAgo.toString()),
                null,
                null,
                null,
                "1"
            )
            val isDup = cursor.use { it.moveToFirst() }
            if (isDup) {
                return -1L
            }

            val values = ContentValues().apply {
                put(COL_PACKAGE_NAME, pkgName)
                put(COL_TITLE, title)
                put(COL_TEXT, text)
                put(COL_BIG_TEXT, bigText)
                put(COL_SUB_TEXT, subText)
                put(COL_POST_TIME, postTime)
                put(COL_PROCESSED, 0)
                put(COL_CREATED_AT, System.currentTimeMillis())
            }

            db.insert(TABLE_NAME, null, values)
        } catch (e: Exception) {
            -1L
        }
    }

    @Synchronized
    fun getPendingNotifications(): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        return try {
            val db = readableDatabase
            val cursor = db.query(
                TABLE_NAME,
                null,
                "$COL_PROCESSED = 0",
                null,
                null,
                null,
                "$COL_POST_TIME ASC",
                "100" // Drain up to 100 pending notifications at a time
            )

            cursor.use {
                while (it.moveToNext()) {
                    val map = mapOf<String, Any?>(
                        "id" to it.getLong(it.getColumnIndexOrThrow(COL_ID)),
                        "packageName" to it.getString(it.getColumnIndexOrThrow(COL_PACKAGE_NAME)),
                        "title" to it.getString(it.getColumnIndexOrThrow(COL_TITLE)),
                        "text" to it.getString(it.getColumnIndexOrThrow(COL_TEXT)),
                        "bigText" to it.getString(it.getColumnIndexOrThrow(COL_BIG_TEXT)),
                        "subText" to it.getString(it.getColumnIndexOrThrow(COL_SUB_TEXT)),
                        "postTime" to it.getLong(it.getColumnIndexOrThrow(COL_POST_TIME))
                    )
                    list.add(map)
                }
            }
            list
        } catch (e: Exception) {
            emptyList()
        }
    }

    @Synchronized
    fun markProcessed(id: Long) {
        try {
            val db = writableDatabase
            val values = ContentValues().apply {
                put(COL_PROCESSED, 1)
            }
            db.update(TABLE_NAME, values, "$COL_ID = ?", arrayOf(id.toString()))
        } catch (_: Exception) {}
    }

    @Synchronized
    fun markProcessed(ids: List<Long>) {
        if (ids.isEmpty()) return
        try {
            val db = writableDatabase
            db.beginTransaction()
            try {
                val values = ContentValues().apply {
                    put(COL_PROCESSED, 1)
                }
                for (id in ids) {
                    db.update(TABLE_NAME, values, "$COL_ID = ?", arrayOf(id.toString()))
                }
                db.setTransactionSuccessful()
            } finally {
                db.endTransaction()
            }
        } catch (_: Exception) {}
    }

    @Synchronized
    fun pruneOldNotifications(daysToKeep: Int = 14) {
        try {
            val db = writableDatabase
            val cutoff = System.currentTimeMillis() - (daysToKeep.toLong() * 24 * 60 * 60 * 1000)
            db.delete(TABLE_NAME, "$COL_PROCESSED = 1 AND $COL_CREATED_AT < ?", arrayOf(cutoff.toString()))
        } catch (_: Exception) {}
    }
}
