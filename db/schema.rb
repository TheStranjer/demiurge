# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_16_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "characters", force: :cascade do |t|
    t.integer "awareness", null: false
    t.integer "charisma", null: false
    t.datetime "created_at", null: false
    t.integer "dexterity", null: false
    t.integer "endurance", null: false
    t.integer "finesse", null: false
    t.integer "intelligence", null: false
    t.string "name", null: false
    t.boolean "non_player_character", default: false, null: false
    t.string "sex", null: false
    t.integer "strength", null: false
    t.integer "tact", null: false
    t.datetime "updated_at", null: false
    t.integer "willpower", null: false
    t.integer "world_id", null: false
    t.index ["world_id"], name: "index_characters_on_world_id"
  end

  create_table "grok_calls", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "grokable_id", null: false
    t.string "grokable_type", null: false
    t.jsonb "payload", null: false
    t.jsonb "response"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.index ["grokable_type", "grokable_id"], name: "index_grok_calls_on_grokable"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "worlds", force: :cascade do |t|
    t.text "core_concept", null: false
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_worlds_on_user_id"
  end

  add_foreign_key "characters", "worlds"
  add_foreign_key "sessions", "users"
  add_foreign_key "worlds", "users"
end
