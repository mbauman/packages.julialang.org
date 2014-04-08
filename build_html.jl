using JSON

function humanStatus(status)
    if status == "full_pass"
        return "Tests pass."
    elseif status == "full_fail"
        return "Tests fail, but package loads."
    elseif status == "using_pass"
        return "No tests, but package loads."
    elseif status == "using_fail"
        return "Package doesn't load."
    else
        return "Package was untestable due to binary dependency."
    end
end

# First get head and tail
index_head = readall("index.html.head")
index_tail = readall("index.html.tail")
listing = String[]

# Load package listing
pkgs = JSON.parse(readall("all.json"))

for pkg in pkgs
    cur_listing  = "<div class=\"container pkglisting\" "
    cur_listing *= "data-pkg=\"" * lowercase(pkg["name"])  * "\" "
    cur_listing *= "data-ver=\"" * pkg["jlver"] * "\" "
    cur_listing *= ">\n"

    # First line - Name
    cur_listing *= "<div class=\"row\">\n"
        cur_listing *= "<div class=\"col-xs-12\"><h2><a href=\"" * pkg["url"] * "\">" * pkg["name"] * "</a></h2></div>\n"
    cur_listing *= "</div>\n"

    # Second line - Description
    cur_listing *= "<div class=\"row\">\n"
        cur_listing *= "<div class=\"col-xs-12\"><h4>" * (pkg["githubdesc"] == nothing ? "" : pkg["githubdesc"]) * "</h4></div>\n"
    cur_listing *= "</div>\n"

    # Third line - Info
    cur_listing *= "<div class=\"row\">\n"
        # Version
        cur_listing *= "<div class=\"col-sm-6\"><p><b>Current version: <a href=\"" * 
                        pkg["url"] * "/tree/" * pkg["gitsha"] * "\">" * pkg["version"] * " (" *
                        pkg["gitsha"][1:8] * ")</a></b></p></div>\n"

        # License
        licurl = ""
        if pkg["licfile"] != ""
            licurl = pkg["url"] * "/blob/" * pkg["gitsha"] * "/" * pkg["licfile"]
        else
            licurl = pkg["url"] * "/tree/" * pkg["gitsha"]
        end
        cur_listing *= "<div class=\"col-sm-3\"><p><b>License: <a href=\"" *
                        licurl * "\">" * pkg["license"] * "</a></b></p></div>\n"

        # Owner
        owner = split(pkg["url"],"/")[end-1]
        cur_listing *= "<div class=\"col-sm-3\"><p><b>Author: <a href=\"http://github.com/" *
                        owner * "\">" * owner * "</a></b></p></div>\n"
    cur_listing *= "</div>\n"

    # Fourth line - testing info
    cur_listing *= "<div class=\"row\">\n<div class=\"col-md-12\"><p>\n<b>Test status</b>: "
    cur_listing *= "<a href=\"badges/" * pkg["name"] * "_" * pkg["jlver"] * ".svg" * "\">" *
                   "<img src=\"badges/" * pkg["status"] * ".svg" * "\" alt=\"" * humanStatus(pkg["status"]) * "\"></a> "
    cur_listing *= humanStatus(pkg["status"]) * " "
    cur_listing *= "<a class=\"showlog\" data-pkg=\"" * pkg["name"] * "\" data-ver=\"" * pkg["jlver"] * "\"><span id=\"" * pkg["name"] * "_loglink\">Show log</span></a> - "
    cur_listing *= "<a class=\"showhist\" data-pkg=\"" * pkg["name"] * "\"><span id=\"" * pkg["name"] * "_histlink\">Show history</span></a></p>"
    cur_listing *= "<pre style=\"display: none;\" class=\"testlog\" id=\"" * pkg["name"] * "_log\"></pre>"
    cur_listing *= "<pre style=\"display: none;\" class=\"testhist\" id=\"" * pkg["name"] * "_hist\">" * pkg["hist"] * "</pre>"
    cur_listing *= "</div></div>"


    push!(listing, cur_listing * "<hr></div>")
    #break
end

# Output
fp = open("newindex.html","w")
print(fp, index_head * join(listing,"\n") * index_tail)
close(fp)