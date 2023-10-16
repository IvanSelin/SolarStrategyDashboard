module App
# set up Genie development environmet
using GenieFramework
using Dates
# using StipplePlotly
using PlotlyBase
using Statistics
using DataFrames
using Logging
# using StippleUI
include("lib\\solar_loader.jl")
@genietools



Genie.config.cors_headers["Access-Control-Allow-Origin"]  =  "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]
Genie.config.server_port = 9101

const FILE_PATH = "upload"
const TRACK_DIR = "track"
const WEATHER_DIR = "weather"
mkpath(FILE_PATH)
mkpath(joinpath(FILE_PATH, TRACK_DIR))
mkpath(joinpath(FILE_PATH, WEATHER_DIR))

# add your data analysis code
function mean(x)
    sum(x) / length(x)
end

# add reactive code to make the UI interactive
@app begin
    # reactive variables are tagged with @in and @out
    @private datetime_format = "YYYY-mm-dd HH:MM:SS"
    @in N = 0
    @in route_file = ""
    @in weather_file = ""
    @in start_index = 1
    # @in start_datetime = string(DateTime(2023,1,1,10,0,0))
    @in start_datetime = "2023-01-01 10:00:00"
    @in calculating = false
    @in set_time = false
    @in selected_track = ""
    @in selected_weather = ""
    @in latitude_in = 0.0
    @in longitude_in = 0.0
    @in selecting_location = false
    @in start_energy = 5100.
    @in subtasks_scaling_coef = 5
    @in speeds_scaling_coef = 5

    @out msg = "The average is 0."
    @out calculation_progress = 0.
    @out is_calculating = false
    @out my_msg = "init_val"
    @out index_out = "sample text"
    @out max_track_index = 1
    @out track_files = readdir(joinpath(FILE_PATH, TRACK_DIR))
    @out weather_files = readdir(joinpath(FILE_PATH, WEATHER_DIR))
    @out track_traces = [scatter(
        type="scattermapbox",
        text=[ 10, 5 ],
        lon=[ -90.1744208, -90.9007405 ],
        lat=[ 38.0032799, 38.0021822 ],
        marker_color="fuchsia",
        marker_size=4
      )]
    @out calculation_alert = false
    @out track_not_selected = true
    @out travel_time = 1.
    @out finish_time = DateTime(2023,1,1,0,0,0)
    @out average_speed = 0.
    @out max_energy = 0.
    @out min_energy = 0.
    @out results_ready = false

    @out track_layout = PlotlyBase.Layout(
            dragmode="zoom",
            mapbox_style="open-street-map",
            mapbox_center_lat=38,
            mapbox_center_lon=-90,
            mapbox_zoom=3,
            # width=400,
            height=300,
            margin_l=0,
            margin_r=0,
            margin_t=0,
            margin_b=0
    )
    @out track_altitude_traces = [
    ]
    @out track_altitude_layout = PlotlyBase.Layout(
        height=250,
        margin_l=0,
        margin_r=0,
        # margin_t=0,
        margin_b=0,
        # margin_pad=0
        title_text="Track altitude (distance)",
        xaxis_title_text="Distance (m)",
        yaxis_title_text="Altitude (m)",
        showlegend=false
    )

    @out speeds_traces = [
    ]
    @out speeds_layout = PlotlyBase.Layout(
    )

    @out energies_traces = [
    ]
    @out energies_layout = PlotlyBase.Layout(
        height=250,
        margin_l=0,
        margin_r=0,
        # margin_t=0,
        margin_b=0,
        margin_pad=0,
        showlegend=false,
        title_text="Energy (distance)",
        xaxis_title_text="Distance (m)",
        yaxis_title_text="Energy (Wt*h)"
    )

    # @private defines a non-reactive variable
    @private result = 0.0
    @private track_df = DataFrame()
    @private segments_df = DataFrame()
    # @private weather_coeff = Matrix{Float64}
    # @private weather_coeff = Array{Float64,2}
    # @private edges_lat = Vector{Float64}
    # @private edges_lon = Vector{Float64}
    @private weather_density_df = DataFrame(lat=Float64[], lon=Float64[], z=Float64[])
    # @private weather_weights = Vector{Float64}
    # @private segments_df

    # watch a variable and execute a block of code when
    # its value changes
    @onchange N begin
        # the values of result and msg in the UI will
        # be automatically updated
        result = mean(rand(N))
        msg = "The average is $result."
    end

    @onchange calculating begin
        # if route_file == "" || weather_file == ""
        #     calculation_alert = true
        # end
        # calculating = true
        is_calculating = true

        @info "Starting calculation"

        optim_track_df = track_df[start_index:end,:]
        optim_segments_df = segments_df[start_index:end,:]

        results = iterative_optimization(
            optim_track_df,
            optim_segments_df,
            subtasks_scaling_coef,
            speeds_scaling_coef,
            start_energy,
            DateTime(start_datetime, datetime_format)
        )

        final_result = last(results).solution
        speeds = final_result.speeds
        energies = final_result.energies

        speeds_traces = [
            scatter(
                x=get_mean_data(optim_track_df.distance),
                y=speeds,
                mode="lines",
                type="scatter",
                line_color="red"
            )
        ]

        speeds_layout = PlotlyBase.Layout(
            height=250,
            margin_l=0,
            margin_r=0,
            # margin_t=0,
            margin_b=0,
            margin_pad=0,
            title_text="Speed (distance)",
            xaxis_title_text="Distance (m)",
            yaxis_title_text="Speed (km/h)",
            showlegend=false,
            xaxis_range=[0, last(track_df.distance)]
        )

        blue_y_data = fill(0., size(track_df.distance,1))

        energies_traces = [
            scatter(
                x=optim_track_df.distance,
                y=energies,
                mode="lines",
                type="scatter",
                line_width="2",
                line_color="red"
            ),
            scatter(
                x=track_df.distance,
                y=blue_y_data,
                mode="lines",
                type="scatter",
                line_width="4",
                line_color="blue"
            )
        ]

        @info "Finishing calculation"
        travel_time = last(final_result.seconds)
        finish_time = last(final_result.times)
        average_speed = mean(final_result.speeds)
        min_energy = minimum(final_result.energies)
        is_calculating = false
        results_ready = true
    end

    @onchange start_datetime begin
        
    end

    @onchange route_file begin
        
    end

    @onchange weather_file begin
        
    end

    @onbutton set_time begin
        # start_datetime = string(Dates.now())
        start_datetime = Dates.format(now(), "YYYY-mm-dd HH:MM:SS")
    end

    function get_map_traces(track_data, split_index, weather_df)
        before_df = track_data[1:split_index, :]
        after_df = track_data[split_index:end,:]

        lats_before = before_df.latitude
        lons_before = before_df.longitude

        lats_after = after_df.latitude
        lons_after = after_df.longitude

        trace_before = scatter(
            type="scattermapbox",
            lon=lons_before,
            lat=lats_before,
            marker_color="green",
            line_color="green",
            marker_size=4,
            mode="lines+markers",
            name="passed"
        )

        trace_after = scatter(
            type="scattermapbox",
            lon=lons_after,
            lat=lats_after,
            marker_color="red",
            line_color="red",
            marker_size=4,
            mode="lines+markers",
            name="prediction"
        )

        weather_trace = densitymapbox(
            lat=weather_df.lat,
            lon=weather_df.lon,
            z=weather_df.z,
            opacity=0.5
        )

        track_altitude_traces = [
            scatter(
                x=before_df.distance,
                y=before_df.altitude,
                mode="lines",
                type="scatter",
                line_color="green",
                name="passed"
            ),
            scatter(
                x=after_df.distance,
                y=after_df.altitude,
                mode="lines",
                type="scatter",
                line_color="red",
                name="prediction"
            )
        ]

        traces = [trace_before, trace_after, weather_trace]
        # track_traces = [trace_before, trace_after]
        layout = PlotlyBase.Layout(
            geo_fitbounds="locations",
			# autosize=true,
            dragmode="zoom",
            mapbox_style="open-street-map",
            mapbox_center_lat=mean(track_data.latitude),
            mapbox_center_lon=mean(track_data.longitude),
            mapbox_zoom=3,
            # autosize=true,
            height=300,
            margin_l=0,
            margin_r=0,
            margin_t=0,
            margin_b=0,
            legend_title_side="top",
            legend_orientation="h"
        )

        return traces, layout, track_altitude_traces
    end

    @onchange start_index begin
        track_traces, track_layout, track_altitude_traces = get_map_traces(track_df, start_index, weather_density_df)
        latitude_in = track_df.latitude[start_index]
        longitude_in = track_df.longitude[start_index]
    end

    @onchange selected_weather begin

        # enter some function to re-draw the map?
        # or re-calculate traces and layout

        # у нас есть 3 источника (возможно потом и 4), через которые обновляются данные карты
        # а код обновления карты везде должен дёргаться один и тот же
        # НО есть проблема: внутри обычных функций @out переменные не меняются
        # лучше всего сделать функцию, которой передавать параметры и чтобы внутри неё всё менялось
        # если что, пусть возвращает несколько значений

        println(selected_weather)
        weather_coeff, edges_lat, edges_lon = read_weather_json(joinpath(FILE_PATH, WEATHER_DIR, selected_weather))

        weather_density_df = generate_density_data(weather_coeff, edges_lat, edges_lon)

        weather_weights = calculate_weather_weights_for_segments(
            weather_coeff,
            edges_lat,
            edges_lon,
            segments_df
        )
        segments_df.weather_coeff = weather_weights

        track_traces, track_layout, track_altitude_traces = get_map_traces(track_df, start_index, weather_density_df)
        
    end

    @onchange selected_track begin
        println(selected_track)
        track_df, segments_df = get_track_and_segments(joinpath(FILE_PATH, TRACK_DIR, selected_track))

        max_track_index = size(segments_df,1)
        start_index = min(start_index, max_track_index)
        track_traces, track_layout, track_altitude_traces = get_map_traces(track_df, start_index, weather_density_df)
        track_not_selected = false
    end

    @onchange selecting_location begin
        euclidean_distance = sqrt.( (track_df.latitude .- latitude_in) .^ 2 .+ (track_df.longitude .- longitude_in) .^ 2 )
        val, index = findmin(euclidean_distance)
        start_index = index
    end

    route("/track", method = POST) do
        files = Genie.Requests.filespayload()
        for f in files
            write(joinpath(FILE_PATH, TRACK_DIR, f[2].name), f[2].data)
        end
        track_files = readdir(joinpath(FILE_PATH, TRACK_DIR))
        if length(files) == 0
            @info "No file uploaded"
        end
        return "Upload finished"
    end

    route("/weather", method = POST) do
        files = Genie.Requests.filespayload()
        for f in files
            write(joinpath(FILE_PATH, WEATHER_DIR, f[2].name), f[2].data)
        end
        weather_files = readdir(joinpath(FILE_PATH, WEATHER_DIR))
        if length(files) == 0
            @info "No file uploaded"
        end
        return "Upload finished"
    end

    
end

function ui()
    [
        row([
            cell(class="st-module", bignumber("Caption", 42))
        ])
    ]
end

# register a new route and the page that will begin
# loaded on access
meta = Dict(
    "og:title" => "Solar strategy tool",
    "og:desciption" => "Solar strategy dashboard app",
    "og:image" => "text"
)
layout = DEFAULT_LAYOUT(meta = meta)
@page("/", "app.jl.html", layout)
@page("/code", ui)

# debug_logger = ConsoleLogger(stderr, Logging.Debug)
# global_logger(debug_logger)

end
