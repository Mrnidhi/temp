"""
PPR pipeline - Stage 5: author the finished Tableau workbook (.twbx).

Self-contained package: both CSV sources embedded, all calculations included.
Sheets:
    P&PR Scorecard     - the mandated 13-metric matrix (center vs benchmarks)
    Custom Date Window - every metric recomputed for any date range; each event
                         row carries its own event date, so the range filter is
                         correct per metric (enrollment/TTP/delivery/infusion)
Dashboard "P&PR Dashboard" combines both with one center dropdown and the date
slider, styled to the Iovance palette (navy #17344F, lime #9DC13C).

Out: ../PPR Dashboard.twbx
"""
import os
import shutil
import zipfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ANA = os.path.join(HERE, "..", "analysis")
SC_CSV = os.path.join(ANA, "ppr_scorecard_tidy.csv")
DW_CSV = os.path.join(ANA, "ppr_datewindow_long.csv")
OUT = os.path.join(HERE, "..", "PPR Dashboard.twbx")
SC, DW = "federated.sc", "federated.dw"
NAVY, LIME = "#17344F", "#9DC13C"

SC_COLS = [("scope", "string"), ("center", "string"), ("col_group", "string"),
           ("col_label", "string"), ("col_order", "integer"), ("metric_group", "string"),
           ("metric", "string"), ("metric_order", "integer"), ("value_type", "string"),
           ("value", "real"), ("row_label", "string"), ("col_final", "string"),
           ("value_display", "string")]
DW_COLS = [("center", "string"), ("metric_group", "string"), ("metric", "string"),
           ("metric_order", "integer"), ("agg", "string"), ("event_date", "date"),
           ("value", "real")]
REMOTE = {"string": "129", "integer": "20", "real": "5", "date": "7"}


def datasource(name, caption, conn, fname, cols, extra=""):
    col_xml = "\n".join(
        f"    <column datatype='{dt}' name='[{n}]' role='{'measure' if dt=='real' else 'dimension'}' "
        f"type='{'quantitative' if dt=='real' else ('ordinal' if dt=='date' else 'nominal')}' />"
        for n, dt in cols)
    meta = "\n".join(f"""        <metadata-record class='column'>
          <remote-name>{n}</remote-name><remote-type>{REMOTE[dt]}</remote-type>
          <local-name>[{n}]</local-name><parent-name>[{fname}]</parent-name>
          <remote-alias>{n}</remote-alias><ordinal>{i}</ordinal>
          <local-type>{dt}</local-type><contains-null>true</contains-null>
        </metadata-record>""" for i, (n, dt) in enumerate(cols))
    rel_cols = "\n".join(f"            <column datatype='{dt}' name='{n}' ordinal='{i}' />"
                         for i, (n, dt) in enumerate(cols))
    return f"""    <datasource caption='{caption}' inline='true' name='{name}' version='18.1'>
      <connection class='federated'>
        <named-connections>
          <named-connection caption='{caption}' name='{conn}'>
            <connection class='textscan' directory='Data' filename='{fname}' password='' server='' />
          </named-connection>
        </named-connections>
        <relation connection='{conn}' name='{fname}' table='[{fname}]' type='table'>
          <columns character-set='UTF-8' header='yes' locale='en_US' separator=','>
{rel_cols}
          </columns>
        </relation>
        <metadata-records>
{meta}
        </metadata-records>
      </connection>
{col_xml}
{extra}
    </datasource>"""


# Scorecard: keep the picked center's cells plus the fixed national benchmark block.
SC_EXTRA = f"""    <column caption='Keep Row' datatype='boolean' name='[Calculation_keep]' role='dimension' type='nominal'>
      <calculation class='tableau' formula='([scope] = &quot;Center&quot; AND [center] = [Parameters].[pCenter]) OR [scope] = &quot;National&quot;' />
    </column>"""

# Date window: filter to the picked center; Result renders by aggregation contract
# (sum = count, avg = 1-decimal days, rate = percent from the 0/1 mfg-start rows).
DW_EXTRA = f"""    <column caption='Keep Center' datatype='boolean' name='[Calculation_kc]' role='dimension' type='nominal'>
      <calculation class='tableau' formula='[center] = [Parameters].[pCenter]' />
    </column>
    <column caption='Result' datatype='string' name='[Calculation_res]' role='measure' type='nominal'>
      <calculation class='tableau' formula='IF ATTR([agg]) = &quot;rate&quot; THEN STR(ROUND(AVG([value]) * 100, 1)) + &quot;%&quot;&#10;ELSEIF ATTR([agg]) = &quot;avg&quot; THEN STR(ROUND(AVG([value]), 1))&#10;ELSE STR(INT(SUM([value]))) END' />
    </column>"""

PARAMS = """    <datasource hasconnection='false' inline='true' name='Parameters' version='18.1'>
      <column caption='pCenter' datatype='string' name='[pCenter]' param-domain-type='list' role='measure' type='nominal' value='&quot;__DEFAULT__&quot;'>
        <members>
__MEMBERS__
        </members>
      </column>
    </datasource>"""

WS_SCORECARD = f"""  <worksheet name='P&amp;PR Scorecard'>
    <table>
      <view>
        <datasources>
          <datasource caption='PPR Scorecard' name='{SC}' />
        </datasources>
        <datasource-dependencies datasource='{SC}'>
          <column datatype='boolean' name='[Calculation_keep]' role='dimension' type='nominal'>
            <calculation class='tableau' formula='([scope] = &quot;Center&quot; AND [center] = [Parameters].[pCenter]) OR [scope] = &quot;National&quot;' />
          </column>
          <column datatype='string' name='[metric_group]' role='dimension' type='nominal' />
          <column datatype='string' name='[row_label]' role='dimension' type='nominal' />
          <column datatype='string' name='[col_final]' role='dimension' type='nominal' />
          <column datatype='string' name='[value_display]' role='dimension' type='nominal' />
          <column-instance column='[metric_group]' derivation='None' name='[none:metric_group:nk]' pivot='key' type='nominal' />
          <column-instance column='[row_label]' derivation='None' name='[none:row_label:nk]' pivot='key' type='nominal' />
          <column-instance column='[col_final]' derivation='None' name='[none:col_final:nk]' pivot='key' type='nominal' />
          <column-instance column='[value_display]' derivation='Attribute' name='[attr:value_display:nk]' pivot='key' type='nominal' />
          <column-instance column='[Calculation_keep]' derivation='None' name='[none:Calculation_keep:nk]' pivot='key' type='nominal' />
        </datasource-dependencies>
        <filter class='categorical' column='[{SC}].[none:Calculation_keep:nk]'>
          <groupfilter function='member' level='[{SC}].[none:Calculation_keep:nk]' member='true' />
        </filter>
        <aggregation value='true' />
      </view>
      <style>
        <style-rule element='header'><format attr='background-color' value='{NAVY}' /></style-rule>
      </style>
      <panes><pane selection-relaxation-option='selection-relaxation-allow'>
        <view><breakdown value='auto' /></view>
        <mark class='Text' />
        <encodings><text column='[{SC}].[attr:value_display:nk]' /></encodings>
      </pane></panes>
      <rows>([{SC}].[none:metric_group:nk] / [{SC}].[none:row_label:nk])</rows>
      <cols>[{SC}].[none:col_final:nk]</cols>
    </table>
  </worksheet>"""

WS_WINDOW = f"""  <worksheet name='Custom Date Window'>
    <table>
      <view>
        <datasources>
          <datasource caption='PPR Date Window' name='{DW}' />
        </datasources>
        <datasource-dependencies datasource='{DW}'>
          <column datatype='boolean' name='[Calculation_kc]' role='dimension' type='nominal'>
            <calculation class='tableau' formula='[center] = [Parameters].[pCenter]' />
          </column>
          <column datatype='string' name='[Calculation_res]' role='measure' type='nominal'>
            <calculation class='tableau' formula='IF ATTR([agg]) = &quot;rate&quot; THEN STR(ROUND(AVG([value]) * 100, 1)) + &quot;%&quot;&#10;ELSEIF ATTR([agg]) = &quot;avg&quot; THEN STR(ROUND(AVG([value]), 1))&#10;ELSE STR(INT(SUM([value]))) END' />
          </column>
          <column datatype='string' name='[metric_group]' role='dimension' type='nominal' />
          <column datatype='string' name='[metric]' role='dimension' type='nominal' />
          <column datatype='integer' name='[metric_order]' role='dimension' type='ordinal' />
          <column datatype='date' name='[event_date]' role='dimension' type='ordinal' />
          <column datatype='string' name='[agg]' role='dimension' type='nominal' />
          <column datatype='real' name='[value]' role='measure' type='quantitative' />
          <column-instance column='[metric_group]' derivation='None' name='[none:metric_group:nk]' pivot='key' type='nominal' />
          <column-instance column='[metric_order]' derivation='None' name='[none:metric_order:nk]' pivot='key' type='ordinal' />
          <column-instance column='[metric]' derivation='None' name='[none:metric:nk]' pivot='key' type='nominal' />
          <column-instance column='[Calculation_kc]' derivation='None' name='[none:Calculation_kc:nk]' pivot='key' type='nominal' />
          <column-instance column='[event_date]' derivation='None' name='[none:event_date:qk]' pivot='key' type='quantitative' />
          <column-instance column='[Calculation_res]' derivation='User' name='[usr:Calculation_res:nk]' pivot='key' type='nominal' />
        </datasource-dependencies>
        <filter class='categorical' column='[{DW}].[none:Calculation_kc:nk]'>
          <groupfilter function='member' level='[{DW}].[none:Calculation_kc:nk]' member='true' />
        </filter>
        <filter class='quantitative' column='[{DW}].[none:event_date:qk]' included-values='in-range' />
        <aggregation value='true' />
      </view>
      <style>
        <style-rule element='header'><format attr='background-color' value='{NAVY}' /></style-rule>
      </style>
      <panes><pane selection-relaxation-option='selection-relaxation-allow'>
        <view><breakdown value='auto' /></view>
        <mark class='Text' />
        <encodings><text column='[{DW}].[usr:Calculation_res:nk]' /></encodings>
      </pane></panes>
      <rows>([{DW}].[none:metric_group:nk] / ([{DW}].[none:metric_order:nk] / [{DW}].[none:metric:nk]))</rows>
    </table>
  </worksheet>"""

DASHBOARD = f"""  <dashboards>
    <dashboard name='P&amp;PR Dashboard'>
      <style />
      <size maxheight='850' maxwidth='1400' minheight='850' minwidth='1400' />
      <datasources>
        <datasource caption='PPR Date Window' name='{DW}' />
      </datasources>
      <zones>
        <zone h='100000' id='1' type-v2='layout-basic' w='100000' x='0' y='0'>
          <zone h='7000' id='2' type-v2='text' w='100000' x='0' y='0'>
            <formatted-text>
              <run bold='true' fontcolor='#FFFFFF' fontname='Segoe UI' fontsize='16'>  IOVANCE  |  P&amp;PR Scorecard - Patient &amp; Process Review</run>
            </formatted-text>
            <zone-style><format attr='background-color' value='{NAVY}' /></zone-style>
          </zone>
          <zone h='86000' id='3' type-v2='layout-flow' param='horz' w='100000' x='0' y='7000'>
            <zone h='86000' id='4' name='P&amp;PR Scorecard' w='56000' x='0' y='7000' />
            <zone h='86000' id='5' name='Custom Date Window' w='30000' x='56000' y='7000' />
            <zone h='86000' id='6' type-v2='layout-flow' param='vert' w='14000' x='86000' y='7000'>
              <zone h='20000' id='7' mode='typeinlist' param='[Parameters].[pCenter]' type-v2='paramctrl' w='14000' x='86000' y='7000' />
              <zone h='24000' id='8' mode='dateslider' param='[{DW}].[none:event_date:qk]' type-v2='filter' w='14000' x='86000' y='27000'>
                <zone-style><format attr='border-color' value='{LIME}' /><format attr='border-style' value='solid' /><format attr='border-width' value='1' /></zone-style>
              </zone>
            </zone>
          </zone>
          <zone h='7000' id='9' type-v2='text' w='100000' x='0' y='93000'>
            <formatted-text>
              <run bold='true' fontcolor='{NAVY}' fontname='Segoe UI' fontsize='10'>  ADVANCING IMMUNO-ONCOLOGY   |   Confidential for Internal Use Only</run>
            </formatted-text>
            <zone-style><format attr='background-color' value='{LIME}' /></zone-style>
          </zone>
        </zone>
      </zones>
    </dashboard>
  </dashboards>"""


def main():
    import csv
    with open(SC_CSV) as f:
        centers = sorted({r["center"] for r in csv.DictReader(f) if r["scope"] == "Center"})
    members = "\n".join(f"          <member value='&quot;{c}&quot;' />" for c in centers)
    params = PARAMS.replace("__MEMBERS__", members).replace("__DEFAULT__", centers[0])

    twb = f"""<?xml version='1.0' encoding='utf-8' ?>
<workbook original-version='18.1' source-build='2023.3.0' source-platform='mac' version='18.1'>
  <preferences />
  <datasources>
{params}
{datasource(SC, "ppr_scorecard_tidy", "textscan.sc", "ppr_scorecard_tidy.csv", SC_COLS, SC_EXTRA)}
{datasource(DW, "ppr_datewindow_long", "textscan.dw", "ppr_datewindow_long.csv", DW_COLS, DW_EXTRA)}
  </datasources>
  <worksheets>
{WS_SCORECARD}
{WS_WINDOW}
  </worksheets>
{DASHBOARD}
  <windows>
    <window class='dashboard' name='P&amp;PR Dashboard'><viewpoints /></window>
  </windows>
</workbook>
"""
    ET.fromstring(twb)  # fail fast on malformed XML
    build = os.path.join(HERE, "_wb_build")
    if os.path.exists(build):
        shutil.rmtree(build)
    os.makedirs(os.path.join(build, "Data"))
    with open(os.path.join(build, "PPR Dashboard.twb"), "w", encoding="utf-8") as f:
        f.write(twb)
    shutil.copy(SC_CSV, os.path.join(build, "Data"))
    shutil.copy(DW_CSV, os.path.join(build, "Data"))
    if os.path.exists(OUT):
        os.remove(OUT)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(build, "PPR Dashboard.twb"), "PPR Dashboard.twb")
        for fn in os.listdir(os.path.join(build, "Data")):
            z.write(os.path.join(build, "Data", fn), f"Data/{fn}")
    shutil.rmtree(build)
    print(f"wrote PPR Dashboard.twbx ({os.path.getsize(OUT)//1024} KB, {len(centers)} centers)")


if __name__ == "__main__":
    main()
