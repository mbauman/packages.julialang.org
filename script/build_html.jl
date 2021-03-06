#######################################################################
# packages.julialang.org
# build_html.jl
# Build the actual site by sticking together a header and footer
#######################################################################

using JSON
using PyPlot
using PackageFuncs

# hist_to_html
# Take a matrix [dates pkgver status] and turns it into a simple
# multiline string that is used in the dropdown for each individual
# package
function hist_to_html(hist)
    output_strs = {}

    pos = size(hist,1)
    cur_start_date = date_nice(hist[pos,1])
    cur_end_date   = date_nice(hist[pos,1])
    cur_version    = hist[pos,2]
    cur_status     = HUMANSTATUS[hist[pos,3]]
    while true
        pos -= 1
        if pos == 0
            # End of history
            push!(output_strs, cur_start_date * " to " * cur_end_date *
                    ", v" * cur_version * ", " * cur_status * "\n")
            break
        end
        pos_date    = date_nice(hist[pos,1])
        pos_version = hist[pos,2]
        pos_status  = HUMANSTATUS[hist[pos,3]]
        if pos_version != cur_version || pos_status != cur_status
            # Change in state
            push!(output_strs, cur_start_date * " to " * cur_end_date *
                    ", v" * cur_version * ", " * cur_status * "\n")
            cur_start_date  = pos_date
            cur_end_date    = pos_date
            cur_version     = pos_version
            cur_status      = pos_status
        else
            # No changes to worry about it
            cur_end_date = pos_date
        end
    end

    return join(reverse(output_strs))
end


# generate_changelog
# Take the history database and generate an HTML list of the changes
function generate_changelog(hist_db, pkg_set, date_set)
    changes = [date=>{} for date in date_set]

    # Walk through every package and day
    for pkg in pkg_set
        key = NIGHTLYVER*pkg
        !(key in keys(hist_db)) && continue
        hist = hist_db[key]
        hist_size = size(hist,1)
        for i = 1:hist_size
            status  = hist[i,3]
            prev    = i < hist_size ? hist[i+1,3] : "new"
            status != prev && push!(changes[hist[i,1]], (pkg, prev, status))
        end
    end

    # Convert to HTML
    function day_to_list(date)
        length(changes[date]) == 0 && return "<h4>$date - no changes.</h4>\n"
        function pkg_to_item(pkg_change)
            pkg, prev, now = pkg_change
            "<li><b class=\"$now\">$pkg</b> " * (
                prev == "new" ?
                    "added to METADATA, status is '$(HUMANSTATUS[now])'" :
                    "changed to '$(HUMANSTATUS[now])' from '$(HUMANSTATUS[prev])'") *
            "</li>\n"
        end
        "<h4>$date</h4><ul>\n" * join(sort(map(pkg_to_item, changes[date]))) * "</ul>\n"
    end
    #return "<ul>\n" * join(map(day_to_list, date_set[1:5])) * "</ul>\n"
    return join(map(day_to_list, date_set[1:5]))
end


# generate_totals
# Take the history database and generate a dictionary of status counts
function generate_totals(hist_db, pkg_set, date_set)
    totals  = [date => ["full_pass" => 0,     "full_fail" => 0,
                        "using_pass" => 0,    "using_fail" => 0,
                        "not_possible" => 0,  "total" => 0]
                        for date in date_set]
    for pkg in pkg_set
        key = NIGHTLYVER*pkg
        !(key in keys(hist_db)) && continue
        hist = hist_db[key]
        for i = 1:size(hist,1)
            totals[hist[i,1]][hist[i,3]] += 1
            totals[hist[i,1]]["total"] += 1
        end
    end
    return totals
end

# generate_plot
# Take the history database and generate a plot of changes in package
# status counts over time
function generate_plot(hist_db, pkg_set, date_set)
    totals = generate_totals(hist_db, pkg_set, date_set)

    # Turn dictionary into a matrix, and do dates relative to the
    # current day (e.g. "days ago")
    data = zeros(length(date_set), 6)
    baseline_day = strptime("%Y%m%d", date_set[1]).yday
    for row in 1:length(date_set)
        data[row,1] = strptime("%Y%m%d", date_set[row]).yday - baseline_day
        data[row,2] = totals[date_set[row]]["full_pass"]
        data[row,3] = totals[date_set[row]]["full_fail"]
        data[row,4] = totals[date_set[row]]["using_pass"]
        data[row,5] = totals[date_set[row]]["using_fail"]
        data[row,6] = totals[date_set[row]]["not_possible"]
    end

    # Create plot with PyPlot
    plt.plot(data[:,1], data[:,2], color="green", label="Test Pass",  linewidth=2, marker="o")
    plt.plot(data[:,1], data[:,3], color="orange",label="Test Fail",  linewidth=2, marker="o")
    plt.plot(data[:,1], data[:,4], color="blue",  label="Using Pass", linewidth=2, marker="o")
    plt.plot(data[:,1], data[:,5], color="red",   label="Using Fail", linewidth=2, marker="o")
    plt.plot(data[:,1], data[:,6], color="grey",  label="Not Tested", linewidth=2, marker="o")
    plt.legend(loc=7)
    plt.xlabel("Days Ago")
    plt.ylabel("Number of Packages")
    plt.title("Package Test Status Counts for Julia $NIGHTLYVER")
    savefig("../pkghist.png")
end

# generate_table
# Take the history database and generate a table of changes in package
# status counts over time
function generate_table(hist_db, pkg_set, date_set)
    totals = generate_totals(hist_db, pkg_set, date_set)
    
    header= "<table class=\"table healthtable\"><tr>" * "<td>Date</td>" *
            "<td>Test Pass</td>" *      "<td>Test Fail</td>" *
            "<td>Using Pass</td>" *     "<td>Using Fail</td>" *
            "<td>Not Possible</td>" *   "<td>Total</td></tr>"
    function to_td(d,s)
        v = totals[d][s]
        t = totals[d]["total"]
        return string("<td>", v, " (", int(round(v/t*100,0)), "%)</td>")
    end
    rows = map( date ->("<tr><td>$date</td>" *
                        to_td(date,"full_pass") *   to_td(date,"full_fail") *
                        to_td(date,"using_pass") *  to_td(date,"using_fail") *
                        to_td(date,"not_possible")* to_td(date,"total") * "</tr>"),
                date_set)
    return header * join(rows[1:min(5,end)]) * "</table>"
end

#######################################################################

# First get head and tail
index_head = readall("index.html.head")
index_tail = readall("index.html.tail")
listing = String[]

# Load package listing
pkgs = JSON.parse(readall("all.json"))

# Load history
hist_db, pkg_set, date_set = create_hist_db()

for pkg in pkgs
    # Dump dictionary out into locals for easier interpolation
    P_OWNER = split(pkg["url"],"/")[end-1]
    P_NAME  = pkg["name"]
    P_URL   = pkg["url"]
    P_DESC  = pkg["githubdesc"] == nothing ? "" : pkg["githubdesc"]
    P_SHA   = pkg["gitsha"]
    P_VER   = pkg["version"]
    P_DATE  = pkg["gitdate"]
    P_LURL  = pkg["licfile"] != "" ? "$P_URL/blob/$P_SHA/$(pkg["licfile"])" : "$P_URL/tree/$P_SHA"
    P_LIC   = pkg["license"]
    P_STAT  = pkg["status"]
    P_HSTAT = HUMANSTATUS[pkg["status"]]
    P_JLVER = pkg["jlver"]
    P_MINOR = pkg["jlver"][end:end]
    P_LINK  = "http://pkg.julialang.org/?pkg=$P_NAME&ver=$P_JLVER"
    P_SVG   = "http://pkg.julialang.org/badges/$(P_NAME)_$P_JLVER.svg"
    P_SVG2  = "http://pkg.julialang.org/badges/$P_STAT.svg"
    hist_data = hist_to_html(hist_db[pkg["jlver"]*pkg["name"]])

    cur_listing = """
<div class="container pkglisting" data-pkg="$(lowercase(P_NAME))"
 data-owner="$(lowercase(P_OWNER))" data-ver="$(pkg["jlver"])"
 data-status="$(pkg["status"])"   data-lic   ="$(pkg["license"])">
<hr>
<div class="row"><div class="col-xs-12">
<h2><a href="$P_URL">$P_NAME</a></h2>\n
<h4>$P_DESC</h4>
<p>Current version: <a href="$P_URL/tree/$P_SHA" title="$P_SHA">$P_VER</a>
(<abbr class="timeago" title="$P_DATE"></abbr>) /
<a href="$P_LURL">$P_LIC</a> license /
Owner: <a href="http://github.com/$P_OWNER">$P_OWNER</a></p>
<p>Test status: <i class="glyphicon glyphicon-stop $P_STAT"></i> $P_HSTAT
<small>
<a class="showbadge" data-pkg="$P_NAME" data-ver="$P_JLVER">
<span id="$(P_NAME)$(P_MINOR)_badgelink">Get permalink/badge</span></a> -
<a class="showhist" data-pkg="$P_NAME" data-ver="$P_JLVER">
<span id="$(P_NAME)$(P_MINOR)_histlink">Show version and test history</span></a> -
<a class="showlog" data-pkg="$P_NAME" data-ver="$P_JLVER">
<span id="$(P_NAME)$(P_MINOR)_loglink">Show last test log</span></a>
</small></p>
<pre style="display: none;" class="badgelinks" id="$(P_NAME)$(P_MINOR)_badge">
BADGE:     <a href="$P_LINK"><img src="$P_SVG2"></a>
PERMALINK: $P_LINK
BADGE SVG: $P_SVG
MARKDOWN:  [![$P_NAME]($P_SVG)]($P_LINK)
</pre>
<pre style="display: none;" class="testlog" id="$(P_NAME)$(P_MINOR)_log"></pre>
<pre style="display: none;" class="testhist" id="$(P_NAME)$(P_MINOR)_hist">$hist_data</pre>
</div></div></div>"""  # /COL, /ROW, /CONTAINER

    push!(listing, cur_listing)
end

# Build package ecoystem health indicators
generate_plot(hist_db, pkg_set, date_set)
output_table = generate_table(hist_db, pkg_set, date_set)
change_list  = generate_changelog(hist_db, pkg_set, date_set)
health = "<div class=\"container\" id=\"pkgstats\"><div class=\"row\"><div class=\"col-md-6\">" *
         "<img src=\"pkghist.png\" alt=\"Package test history\" class=\"img-responsive\">" *
         output_table *
         "</div><div class=\"col-md-6\">" * 
         change_list * 
         "</div></div></div>"

# Output
fp = open("../index.html","w")
print(fp, index_head * health * join(listing,"\n") * index_tail)
close(fp)