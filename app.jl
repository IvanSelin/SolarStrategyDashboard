module App
# set up Genie development environmet
using GenieFramework
using Dates
# using StipplePlotly
using PlotlyBase
using Statistics
using DataFrames
# using StippleUI
# include(joinpath("lib","track.jl"))
# include(joinpath("lib","weather.jl"))
include("lib\\solar_loader.jl")
@genietools



Genie.config.cors_headers["Access-Control-Allow-Origin"]  =  "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

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

# @handlers begin
#     @in calculating = false
#     @out is_calculating = false
#     @out calculation_progress = 0.

#     @onchange calculating begin
#         is_calculating = true
#         calculation_progress = 0.
#         sleep(0.5)
#         calculation_progress = 0.5
#     end
# end

# add reactive code to make the UI interactive
@app begin
    # reactive variables are tagged with @in and @out
    @in N = 0
    @in route_file = ""
    @in weather_file = ""
    @in start_index = 1
    @in start_datetime = string(DateTime(2023,1,1,10,0,0))
    @in calculating = false
    @in set_time = false
    @in selected_track = ""
    @in selected_weather = ""

    @out msg = "The average is 0."
    @out calculation_progress = 0.
    @out is_calculating = false
    @out my_msg = "init_val"
    @out index_out = "sample text"
    @out max_track_index = 1
    @out track_files = readdir(joinpath(FILE_PATH, TRACK_DIR))
    @out weather_files = readdir(joinpath(FILE_PATH, WEATHER_DIR))
    @out track_trace = [scatter(
        type="scattermapbox",
        text=[ 10, 5 ],
        lon=[ -90.1744208, -90.9007405 ],
        lat=[ 38.0032799, 38.0021822 ],
        marker_color="fuchsia",
        marker_size=4
      )]
    # @out track_trace = [scatter(
    #     x=[1, 2, 3, 4],
    #     y=[10, 15, 13, 17],
    #     mode="lines+markers",
    #     name="Trace 1"
    # )]
    # @out track_layout = PlotlyBase.Layout(
    #     title="A Scatter Plot with Multiple Traces",
    #     xaxis=attr(
    #         title="X Axis Label",
    #         showgrid=false
    #     ),
    #     yaxis=attr(
    #         title="Y Axis Label"
    #         # showgrid=true,
    #         # range=[0, 20]
    #     )
    # )

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
    # @private defines a non-reactive variable
    @private result = 0.0
    @private track_df = DataFrame()
    @private segments_df = DataFrame()
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
        # calculating = true
        my_msg = "it's working"
        is_calculating = true
        calculation_progress = 0
        # calcFunction()
        sleep(0.5)
        calculation_progress = 50
        sleep(0.5)
        calculation_progress = 90
        sleep(0.2)
        calculation_progress = 100
        is_calculating = false
    end
    
    @onchange start_index begin
        # index_out = "sample text "*string(start_index)

        before_df = track_df[1:start_index, :]
        after_df = track_df[start_index:end,:]

        lats_after = after_df.latitude
        lons_after = after_df.longitude

        lats_before = before_df.latitude
        lons_before = before_df.longitude

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


        # lats = [30., 30.]
        # lons = [-100., -101.]
        # track_trace = [scatter(
        #     type="scattermapbox",
        #     text=[ "1", "2" ],
        #     lon=lons,
        #     lat=lats,
        #     marker_color="fuchsia",
        #     marker_size=4
        # )]

        track_trace = [trace_before, trace_after]
        track_layout = PlotlyBase.Layout(
            dragmode="zoom",
            mapbox_style="open-street-map",
            mapbox_center_lat=mean(track_df.latitude),
            mapbox_center_lon=mean(track_df.longitude),
            # mapbox_zoom=2,
            autosize=true,
            height=300,
            margin_l=0,
            margin_r=0,
            margin_t=0,
            margin_b=0,
            legend_title_side="top",
            legend_orientation="h"
        )
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

    # function get_track_plot_traces(start_index)
    #     before_df = track_df[1:start_index, :]
    #     after_df = track_df[start_index:max_index,:]

    #     lats = after_df.latitude
    #     lons = after_df.longitude
    #     println()
    #     trace_after = scatter(
    #         type="scattermapbox",
    #         lon=lons,
    #         lat=lats,
    #         marker_color="fuchsia",
    #         marker_size=4
    #     )
    # end

    function get_map_traces(split_index)
        before_df = track_df[1:split_index, :]
        after_df = track_df[split_index:end,:]

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
        


        # lats = [30., 30.]
        # lons = [-100., -101.]
        # track_trace = [scatter(
        #     type="scattermapbox",
        #     text=[ "1", "2" ],
        #     lon=lons,
        #     lat=lats,
        #     marker_color="fuchsia",
        #     marker_size=4
        # )]

        track_traces = [trace_before, trace_after]
        track_layout = PlotlyBase.Layout(
            dragmode="zoom",
            mapbox_style="open-street-map",
            mapbox_center_lat=mean(track_df.latitude),
            mapbox_center_lon=mean(track_df.longitude),
            # mapbox_zoom=3,
            autosize=true,
            height=300,
            margin_l=0,
            margin_r=0,
            margin_t=0,
            margin_b=0,
            legend_title_side="top",
            legend_orientation="h"
        )

        return track_traces, track_layout
    end


    @onchange selected_weather begin

        # enter some function to re-draw the map?
        # or re-calculate traces and layout

        # у нас есть 3 источника (возможно потом и 4), через которые обновляются данные карты
        # а код обновления карты везде должен дёргаться один и тот же
        # НО есть проблема: внутри обычных функций @out переменные не меняются
        # лучше всего сделать функцию, которой передава
        
    end

    @onchange selected_track begin
        println(typeof(selected_track))
        println(selected_track)
        track_df, segments_df = get_track_and_segments(joinpath(FILE_PATH, TRACK_DIR, selected_track))
        max_track_index = size(segments_df,1)
        start_index = min(start_index, max_track_index)

        before_df = track_df[1:start_index, :]
        after_df = track_df[start_index:end,:]

        lats_after = after_df.latitude
        lons_after = after_df.longitude

        lats_before = before_df.latitude
        lons_before = before_df.longitude

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


        # lats = [30., 30.]
        # lons = [-100., -101.]
        # track_trace = [scatter(
        #     type="scattermapbox",
        #     text=[ "1", "2" ],
        #     lon=lons,
        #     lat=lats,
        #     marker_color="fuchsia",
        #     marker_size=4
        # )]

        track_trace = [trace_before, trace_after]
        track_layout = PlotlyBase.Layout(
            dragmode="zoom",
            mapbox_style="open-street-map",
            mapbox_center_lat=mean(track_df.latitude),
            mapbox_center_lon=mean(track_df.longitude),
            mapbox_zoom=3,
            height=300,
            margin_l=0,
            margin_r=0,
            margin_t=0,
            margin_b=0
        )
        
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


# route("/weather", method = POST) do
#     files = Genie.Requests.filespayload()
#     for f in files
#         write(joinpath(FILE_PATH, WEATHER_DIR, f[2].name), f[2].data)
#     end
#     weather_files = readdir(joinpath(FILE_PATH, WEATHER_DIR))
#     if length(files) == 0
#         @info "No file uploaded"
#     end
#     return "Upload finished"
# end

end
