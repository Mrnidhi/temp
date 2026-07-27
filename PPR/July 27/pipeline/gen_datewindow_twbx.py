"""
Date-window proof workbook (.twbx) for Tableau Cloud upload.

One worksheet on the order-grain long events table (analysis/ppr_datewindow_long.csv):
metrics on rows, SUM(value) as the number, and two interactive cards - a date-range
filter on event_date and a single-select center filter. Each row already carries its
metric's own event date, so one date filter counts every metric on the right date.

Upload story: user opens Tableau Cloud > New > Upload Workbook > this .twbx.

Out: ../PPR Date Window.twbx
"""
import os, shutil, zipfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(__file__)
CSV = os.path.join(HERE, "..", "analysis", "ppr_datewindow_long.csv")
OUT = os.path.join(HERE, "..", "PPR Date Window.twbx")
DS = "federated.dw"

COLS = [
    ("center", "string", "dimension"), ("metric_group", "string", "dimension"),
    ("metric", "string", "dimension"), ("metric_order", "integer", "dimension"),
    ("event_date", "date", "dimension"), ("value", "real", "measure"),
]
REMOTE = {"string": "129", "integer": "20", "real": "5", "date": "133"}

def col_defs():
    out = []
    for name, dt, role in COLS:
        agg = "Sum" if role == "measure" else "Count"
        out.append(f"    <column datatype='{dt}' name='[{name}]' role='{role}' "
                   f"type='{'quantitative' if role=='measure' else 'nominal'}' aggregation='{agg}' />")
    return "\n".join(out)

def metadata_records():
    recs = []
    for i, (name, dt, role) in enumerate(COLS):
        recs.append(f"""        <metadata-record class='column'>
          <remote-name>{name}</remote-name>
          <remote-type>{REMOTE[dt]}</remote-type>
          <local-name>[{name}]</local-name>
          <parent-name>[ppr_datewindow_long.csv]</parent-name>
          <remote-alias>{name}</remote-alias>
          <ordinal>{i}</ordinal>
          <local-type>{dt}</local-type>
          <aggregation>{'Sum' if role=='measure' else 'Count'}</aggregation>
          <contains-null>true</contains-null>
        </metadata-record>""")
    return "\n".join(recs)

WS = f"""  <worksheet name='Date Window'>
    <table>
      <view>
        <datasources>
          <datasource caption='PPR Date Window' name='{DS}' />
        </datasources>
        <datasource-dependencies datasource='{DS}'>
          <column datatype='string' name='[center]' role='dimension' type='nominal' />
          <column datatype='string' name='[metric_group]' role='dimension' type='nominal' />
          <column datatype='string' name='[metric]' role='dimension' type='nominal' />
          <column datatype='date' name='[event_date]' role='dimension' type='ordinal' />
          <column datatype='real' name='[value]' role='measure' type='quantitative' aggregation='Sum' />
          <column-instance column='[metric_group]' derivation='None' name='[none:metric_group:nk]' pivot='key' type='nominal' />
          <column-instance column='[metric]' derivation='None' name='[none:metric:nk]' pivot='key' type='nominal' />
          <column-instance column='[value]' derivation='Sum' name='[sum:value:qk]' pivot='key' type='quantitative' />
          <column-instance column='[event_date]' derivation='None' name='[none:event_date:qk]' pivot='key' type='quantitative' />
          <column-instance column='[center]' derivation='None' name='[none:center:nk]' pivot='key' type='nominal' />
        </datasource-dependencies>
        <filter class='categorical' column='[{DS}].[center]'>
          <groupfilter function='level-members' level='[{DS}].[center]' />
        </filter>
        <filter class='quantitative' column='[{DS}].[none:event_date:qk]' included-values='in-range'>
          <min>#2025-01-01#</min>
          <max>#2026-05-05#</max>
        </filter>
        <slices>
          <column>[{DS}].[center]</column>
          <column>[{DS}].[none:event_date:qk]</column>
        </slices>
        <aggregation value='true' />
      </view>
      <style />
      <panes>
        <pane selection-relaxation-option='selection-relaxation-allow'>
          <view><breakdown value='auto' /></view>
          <mark class='Text' />
          <encodings>
            <text column='[{DS}].[sum:value:qk]' />
          </encodings>
        </pane>
      </panes>
      <rows>([{DS}].[none:metric_group:nk] / [{DS}].[none:metric:nk])</rows>
      <cols />
    </table>
    <simple-id uuid='{{9a1b2c3d-0001-0001-0001-000000000001}}' />
  </worksheet>"""

WINDOW = f"""    <window class='worksheet' name='Date Window'>
      <cards>
        <edge name='right'>
          <strip size='160'>
            <card type='filter' param='[{DS}].[none:center:nk]' />
            <card type='filter' param='[{DS}].[none:event_date:qk]' />
          </strip>
        </edge>
      </cards>
      <viewpoint><zoom type='entire-view' /></viewpoint>
    </window>"""

TWB = f"""<?xml version='1.0' encoding='utf-8' ?>
<workbook original-version='18.1' source-build='2023.3.0' source-platform='mac' version='18.1'>
  <preferences>
    <preference name='ui.encoding.shelf.height' value='24' />
    <preference name='ui.shelf.height' value='26' />
  </preferences>
  <datasources>
    <datasource caption='PPR Date Window' inline='true' name='{DS}' version='18.1'>
      <connection class='federated'>
        <named-connections>
          <named-connection caption='ppr_datewindow_long' name='textscan.dw'>
            <connection class='textscan' directory='Data' filename='ppr_datewindow_long.csv'
                        password='' server='' validate='no' />
          </named-connection>
        </named-connections>
        <relation connection='textscan.dw' name='ppr_datewindow_long.csv'
                  table='[ppr_datewindow_long.csv]' type='table'>
          <columns character-set='UTF-8' header='yes' locale='en_US' separator=','>
{chr(10).join(f"            <column datatype='{dt}' name='{n}' ordinal='{i}' />" for i,(n,dt,r) in enumerate(COLS))}
          </columns>
        </relation>
        <metadata-records>
{metadata_records()}
        </metadata-records>
      </connection>
{col_defs()}
    </datasource>
  </datasources>
  <worksheets>
{WS}
  </worksheets>
  <windows>
{WINDOW}
  </windows>
</workbook>
"""

def main():
    ET.fromstring(TWB)  # well-formed check
    build = os.path.join(HERE, "_dw_build")
    if os.path.exists(build): shutil.rmtree(build)
    os.makedirs(os.path.join(build, "Data"))
    with open(os.path.join(build, "PPR Date Window.twb"), "w", encoding="utf-8") as f:
        f.write(TWB)
    shutil.copy(CSV, os.path.join(build, "Data", "ppr_datewindow_long.csv"))
    if os.path.exists(OUT): os.remove(OUT)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(build, "PPR Date Window.twb"), "PPR Date Window.twb")
        z.write(os.path.join(build, "Data", "ppr_datewindow_long.csv"), "Data/ppr_datewindow_long.csv")
    shutil.rmtree(build)
    print(f"wrote {OUT}  ({os.path.getsize(OUT)//1024} KB)  | XML well-formed: True")

if __name__ == "__main__":
    main()
