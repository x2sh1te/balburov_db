DO $$
BEGIN
    CREATE SCHEMA reference_data;

    CREATE TABLE reference_data.temperatures (
        method_code VARCHAR(10),
        height_m INTEGER,
        ground_deviation NUMERIC NOT NULL,
        mean_deviation NUMERIC NOT NULL,
        PRIMARY KEY (method_code, height_m, ground_deviation)
    );

    CREATE TABLE reference_data.wind_speeds (
        method_code VARCHAR(10),
        height_m INTEGER,
        input_value NUMERIC NOT NULL CHECK (input_value >= 0),
        mean_speed NUMERIC NOT NULL CHECK (mean_speed >= 0),
        PRIMARY KEY (method_code, height_m, input_value)
    );

    CREATE TABLE reference_data.wind_directions (
        method_code VARCHAR(10),
        height_m INTEGER,
        correction NUMERIC NOT NULL,
        PRIMARY KEY (method_code, height_m)
    );
END;
$$;
