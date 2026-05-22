/// 用户健康档案与基础生命体征
pub const Profile = struct {
    user_id: []const u8,
    timestamp: i64,
    vitals: Vitals,
    biometrics: Biometrics,
};

pub const Vitals = struct {
    respiratory_rate: f32,
    heart_rate_variability: f32,
    audio_pitch_baseline: f32,
};

pub const Biometrics = struct {
    skin_tone_index: f32,
    posture_score: f32,
    activity_level: f32,
};

pub const UserInput = struct {
    mood: []const u8,
    feelings: []const u8,
    diet: []const u8,
    sleep_quality: u8, // 1-10
};

pub const Measurements = struct {
    height_cm: f32,
    weight_kg: f32,
    systolic_bp: u16, // 收缩压
    diastolic_bp: u16, // 舒张压
    blood_glucose: f32, // mmol/L
    body_temp: f32, // Celsius
};

pub const Medication = struct {
    name: []const u8,
    dosage: []const u8,
    frequency: []const u8,
    start_date: []const u8,
};
