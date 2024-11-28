-- Users table
CREATE TABLE users (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    -- The Argon2 hashed password string for the user.
    password_hash TEXT NOT NULL,

    -- Profile Information
    display_name TEXT,
    full_name TEXT,

    -- Account Status
    is_active INTEGER DEFAULT 1 CHECK (is_active IN (0, 1)),
    email_verified INTEGER DEFAULT 0 CHECK (email_verified IN (0, 1)),

    -- Optional Profile Fields
    profile_image_path TEXT,
    bio TEXT,

    -- Pole Dance Specific
    experience_level TEXT CHECK (experience_level IN ('Beginner', 'Intermediate', 'Advanced', 'Professional')),
    preferred_pole_type TEXT CHECK (preferred_pole_type IN ('Chrome', 'Brass', 'Stainless Steel', 'Titanium Gold', 'Powder Coated')),

    -- Timestamps
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    last_login_at TEXT
);


-- Indexes for better performance
CREATE UNIQUE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_experience ON users(experience_level);
CREATE INDEX idx_training_sessions_user ON training_sessions(user_id);
CREATE INDEX idx_password_reset_tokens_token ON password_reset_tokens(token);
CREATE INDEX idx_email_verification_tokens_token ON email_verification_tokens(token);


-- Main moves table
CREATE TABLE moves (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name TEXT NOT NULL,
    description TEXT,

    -- Difficulty and Level (using TEXT instead of ENUM)
    difficulty TEXT CHECK (difficulty IN ('Beginner', 'Intermediate', 'Advanced', 'Professional')),
    prerequisite_strength_level INTEGER CHECK (prerequisite_strength_level BETWEEN 1 AND 5),
    prerequisite_flexibility_level INTEGER CHECK (prerequisite_flexibility_level BETWEEN 1 AND 5),

    -- Move Characteristics
    is_inverted INTEGER DEFAULT 0 CHECK (is_inverted IN (0, 1)),  -- SQLite boolean
    is_aerial INTEGER DEFAULT 0 CHECK (is_aerial IN (0, 1)),
    pole_position TEXT CHECK (pole_position IN ('Static', 'Spin', 'Both')),

    -- Body Position
    primary_grip_type TEXT CHECK (primary_grip_type IN ('Cup', 'Baseball', 'Split', 'Bracket', 'Twisted', 'Extended')),
    secondary_grip_type TEXT CHECK (secondary_grip_type IN ('Cup', 'Baseball', 'Split', 'Bracket', 'Twisted', 'Extended')),
    entry_position TEXT,
    exit_position TEXT,

    -- Safety
    spotter_required INTEGER DEFAULT 0 CHECK (spotter_required IN (0, 1)),
    crash_mat_recommended INTEGER DEFAULT 0 CHECK (crash_mat_recommended IN (0, 1)),
    grip_aid_recommended INTEGER DEFAULT 0 CHECK (grip_aid_recommended IN (0, 1)),

    -- Training Details
    tips_and_tricks TEXT,
    safety_notes TEXT,

    -- Metrics
    average_learning_time_days INTEGER,
    energy_expenditure_level INTEGER CHECK (energy_expenditure_level BETWEEN 1 AND 5),

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Media table for storing references to images and videos
CREATE TABLE move_media (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    move_id TEXT NOT NULL,
    media_type TEXT CHECK (media_type IN ('image', 'video')),
    file_path TEXT NOT NULL,
    thumbnail_path TEXT,
    is_primary INTEGER DEFAULT 0 CHECK (is_primary IN (0, 1)),
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (move_id) REFERENCES moves(id) ON DELETE CASCADE
);

-- Common mistakes table (one-to-many)
CREATE TABLE move_mistakes (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    move_id TEXT NOT NULL,
    mistake_description TEXT NOT NULL,
    FOREIGN KEY (move_id) REFERENCES moves(id) ON DELETE CASCADE
);

-- Prerequisite moves (many-to-many)
CREATE TABLE move_prerequisites (
    move_id TEXT NOT NULL,
    prerequisite_move_id TEXT NOT NULL,
    PRIMARY KEY (move_id, prerequisite_move_id),
    FOREIGN KEY (move_id) REFERENCES moves(id) ON DELETE CASCADE,
    FOREIGN KEY (prerequisite_move_id) REFERENCES moves(id) ON DELETE CASCADE
);

-- Muscle groups (many-to-many)
CREATE TABLE muscle_groups (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE move_muscle_groups (
    move_id TEXT NOT NULL,
    muscle_group_id TEXT NOT NULL,
    PRIMARY KEY (move_id, muscle_group_id),
    FOREIGN KEY (move_id) REFERENCES moves(id) ON DELETE CASCADE,
    FOREIGN KEY (muscle_group_id) REFERENCES muscle_groups(id) ON DELETE CASCADE
);

-- Style categories (many-to-many)
CREATE TABLE style_categories (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE move_style_categories (
    move_id TEXT NOT NULL,
    category_id TEXT NOT NULL,
    PRIMARY KEY (move_id, category_id),
    FOREIGN KEY (move_id) REFERENCES moves(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES style_categories(id) ON DELETE CASCADE
);

-- Indexes for better performance
CREATE INDEX idx_moves_name ON moves(name);
CREATE INDEX idx_moves_difficulty ON moves(difficulty);
CREATE INDEX idx_move_media_move_id ON move_media(move_id);
CREATE INDEX idx_move_mistakes_move_id ON move_mistakes(move_id);


-- Training sessions table
CREATE TABLE training_sessions (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    user_id TEXT NOT NULL REFERENCES users(id);
    date TEXT NOT NULL DEFAULT (date('now')),
    start_time TEXT NOT NULL DEFAULT (time('now')),
    end_time TEXT,
    duration_minutes INTEGER,

    -- Session Overview
    energy_level INTEGER CHECK (energy_level BETWEEN 1 AND 5),
    mood TEXT CHECK (mood IN ('Great', 'Good', 'Okay', 'Tired', 'Not Great')),
    grip_level INTEGER CHECK (grip_level BETWEEN 1 AND 5),

    -- Session Details
    location TEXT,
    pole_type TEXT CHECK (pole_type IN ('Chrome', 'Brass', 'Stainless Steel', 'Titanium Gold', 'Powder Coated')),
    room_temperature REAL,  -- in Celsius
    humidity_level INTEGER, -- percentage

    -- Notes and Summary
    warm_up_notes TEXT,
    cool_down_notes TEXT,
    general_notes TEXT,

    -- Physical State
    pre_session_pain TEXT,  -- Description of any pre-existing pain/injuries
    post_session_pain TEXT, -- Any new pain or injuries

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Moves practiced during each session
CREATE TABLE session_moves (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    session_id TEXT NOT NULL,
    move_id TEXT NOT NULL,

    -- Progress Tracking
    status TEXT CHECK (status IN (
        'Learning',
        'Practicing',
        'Mastering',
        'Maintenance',
        'Teaching'
    )),

    -- Performance Metrics
    attempts INTEGER DEFAULT 0,
    successful_attempts INTEGER DEFAULT 0,

    -- Quality Assessment (1-5 scale)
    form_quality INTEGER CHECK (form_quality BETWEEN 1 AND 5),
    confidence_level INTEGER CHECK (confidence_level BETWEEN 1 AND 5),

    -- Time spent on this move
    practice_duration_minutes INTEGER,

    -- Notes
    progress_notes TEXT,
    challenges_faced TEXT,
    breakthrough_notes TEXT,

    FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (move_id) REFERENCES moves(id) ON DELETE CASCADE
);

-- Session photos/videos
CREATE TABLE session_media (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    session_id TEXT NOT NULL,
    session_move_id TEXT,  -- Optional: link to specific move in session
    media_type TEXT CHECK (media_type IN ('image', 'video')),
    file_path TEXT NOT NULL,
    thumbnail_path TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (session_move_id) REFERENCES session_moves(id) ON DELETE CASCADE
);

-- Track injuries or areas of concern
CREATE TABLE session_body_tracking (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    session_id TEXT NOT NULL,
    body_part TEXT NOT NULL,
    pain_level INTEGER CHECK (pain_level BETWEEN 0 AND 10),
    pain_type TEXT CHECK (pain_type IN ('Sharp', 'Dull', 'Sore', 'Stiff', 'Bruised')),
    notes TEXT,
    FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE
);

-- Conditioning exercises done during session
CREATE TABLE session_conditioning (
    id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    session_id TEXT NOT NULL,
    exercise_name TEXT NOT NULL,
    sets INTEGER,
    reps INTEGER,
    duration_seconds INTEGER,
    notes TEXT,
    FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE
);

-- Indexes for better performance
CREATE INDEX idx_training_sessions_date ON training_sessions(date);
CREATE INDEX idx_session_moves_session_id ON session_moves(session_id);
CREATE INDEX idx_session_moves_move_id ON session_moves(move_id);
CREATE INDEX idx_session_media_session_id ON session_media(session_id);
CREATE INDEX idx_training_sessions_user ON training_sessions(user_id);
