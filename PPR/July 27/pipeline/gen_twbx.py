"""
PPR pipeline - Stage 3: author the Tableau workbook (.twbx).

Builds a self-contained .twbx: a .twb (XML) that connects to the tidy scorecard CSV,
embedded under Data/. Two worksheets (Center Scorecard, National Benchmarks) mirror
the Excel template and a dashboard combines them with a center selector.

Repoint story: on the office laptop, rerun stages 1-2 against the real Infinity files
to regenerate the CSV, then refresh this workbook - the view is unchanged.

Out: ../PPR Scorecard.twbx
"""
import os
import csv
import shutil
import zipfile
import xml.dom.minidom as minidom
import xml.etree.ElementTree as ET

HERE = os.path.dirname(__file__)
CSV = os.path.join(HERE, "..", "analysis", "ppr_scorecard_tidy.csv")
OUT_TWBX = os.path.join(HERE, "..", "PPR Scorecard.twbx")
DS = "federated.ppr"

# csv columns -> tableau datatype/role
COLS = [
    ("scope", "string", "dimension"), ("center", "string", "dimension"),
    ("col_group", "string", "dimension"), ("col_label", "string", "dimension"),
    ("col_order", "integer", "dimension"), ("metric_group", "string", "dimension"),
    ("metric", "string", "dimension"), ("metric_order", "integer", "dimension"),
    ("value_type", "string", "dimension"), ("value", "real", "measure"),
    ("row_label", "string", "dimension"), ("col_final", "string", "dimension"),
    ("value_display", "string", "dimension"),
]
REMOTE = {"string": "129", "integer": "20", "real": "5"}

def col_defs():
    out = []
    for name, dt, role in COLS:
        agg = "Sum" if role == "measure" else "Count"
        out.append(f"    <column datatype='{dt}' name='[{name}]' role='{role}' "
                   f"type='{'quantitative' if role=='measure' else 'nominal'}' "
                   f"default-format='' aggregation='{agg}' />")
    return "\n".join(out)

def metadata_records():
    recs = []
    for i, (name, dt, role) in enumerate(COLS):
        recs.append(f"""        <metadata-record class='column'>
          <remote-name>{name}</remote-name>
          <remote-type>{REMOTE[dt]}</remote-type>
          <local-name>[{name}]</local-name>
          <parent-name>[ppr_scorecard_tidy.csv]</parent-name>
          <remote-alias>{name}</remote-alias>
          <ordinal>{i}</ordinal>
          <local-type>{dt}</local-type>
          <aggregation>{'Sum' if role=='measure' else 'Count'}</aggregation>
          <contains-null>true</contains-null>
        </metadata-record>""")
    return "\n".join(recs)

def worksheet(name, scope_member, show_center_filter):
    center_filter = ""
    center_slice = ""
    if show_center_filter:
        center_filter = f"""        <filter class='categorical' column='[{DS}].[center]'>
          <groupfilter function='level-members' level='[{DS}].[center]' />
        </filter>"""
        center_slice = f"          <column>[{DS}].[center]</column>\n"
    return f"""  <worksheet name='{name}'>
    <table>
      <view>
        <datasources>
          <datasource caption='PPR Scorecard' name='{DS}' />
        </datasources>
        <datasource-dependencies datasource='{DS}'>
          <column datatype='string' name='[scope]' role='dimension' type='nominal' />
          <column datatype='string' name='[center]' role='dimension' type='nominal' />
          <column datatype='string' name='[metric_group]' role='dimension' type='nominal' />
          <column datatype='string' name='[row_label]' role='dimension' type='nominal' />
          <column datatype='string' name='[col_final]' role='dimension' type='nominal' />
          <column datatype='real' name='[value]' role='measure' type='quantitative' aggregation='Sum' />
          <column-instance column='[metric_group]' derivation='None' name='[none:metric_group:nk]' pivot='key' type='nominal' />
          <column-instance column='[row_label]' derivation='None' name='[none:row_label:nk]' pivot='key' type='nominal' />
          <column-instance column='[col_final]' derivation='None' name='[none:col_final:nk]' pivot='key' type='nominal' />
          <column-instance column='[value]' derivation='Sum' name='[sum:value:qk]' pivot='key' type='quantitative' />
        </datasource-dependencies>
        <filter class='categorical' column='[{DS}].[scope]'>
          <groupfilter function='member' level='[{DS}].[scope]' member='&quot;{scope_member}&quot;' />
        </filter>
{center_filter}
        <slices>
          <column>[{DS}].[scope]</column>
{center_slice}        </slices>
        <aggregation value='true' />
      </view>
      <style />
      <panes>
        <pane selection-relaxation-option='selection-relaxation-allow'>
          <view>
            <breakdown value='auto' />
          </view>
          <mark class='Text' />
          <encodings>
            <text column='[{DS}].[sum:value:qk]' />
          </encodings>
        </pane>
      </panes>
      <rows>([{DS}].[none:metric_group:nk] / [{DS}].[none:row_label:nk])</rows>
      <cols>[{DS}].[none:col_final:nk]</cols>
    </table>
  </worksheet>"""

def dashboard():
    return f"""  <dashboards>
    <dashboard name='P and PR Scorecard'>
      <style />
      <size maxheight='800' maxwidth='1200' minheight='800' minwidth='1200' />
      <zones>
        <zone h='100000' id='1' type-v2='layout-basic' w='100000' x='0' y='0'>
          <zone h='6000' id='3' param='vert' type-v2='title' w='100000' x='0' y='0' />
          <zone h='88000' id='4' type-v2='layout-flow' w='100000' x='0' y='6000'>
            <zone h='88000' id='5' name='Center Scorecard' w='66000' x='0' y='6000'>
              <zone-style><format attr='border-color' value='#000000' /></zone-style>
            </zone>
            <zone h='88000' id='6' name='National Benchmarks' w='34000' x='66000' y='6000'>
              <zone-style><format attr='border-color' value='#000000' /></zone-style>
            </zone>
          </zone>
          <zone h='6000' id='7' mode='checkdropdown' param='[{DS}].[center]' type-v2='filter' w='100000' x='0' y='94000' />
        </zone>
      </zones>
    </dashboard>
  </dashboards>"""

TWB = f"""<?xml version='1.0' encoding='utf-8' ?>
<workbook original-version='18.1' source-build='2023.3.0' source-platform='mac' version='18.1'>
  <preferences>
    <preference name='ui.encoding.shelf.height' value='24' />
    <preference name='ui.shelf.height' value='26' />
  </preferences>
  <datasources>
    <datasource caption='PPR Scorecard' inline='true' name='{DS}' version='18.1'>
      <connection class='federated'>
        <named-connections>
          <named-connection caption='ppr_scorecard_tidy' name='textscan.ppr'>
            <connection class='textscan' directory='Data' filename='ppr_scorecard_tidy.csv'
                        password='' server='' validate='no' />
          </named-connection>
        </named-connections>
        <relation connection='textscan.ppr' name='ppr_scorecard_tidy.csv'
                  table='[ppr_scorecard_tidy.csv]' type='table'>
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
{worksheet("Center Scorecard", "Center", True)}
{worksheet("National Benchmarks", "National", False)}
  </worksheets>
{dashboard()}
  <windows>
    <window class='dashboard' name='P and PR Scorecard'><viewpoints /></window>
  </windows>
</workbook>
"""

def main():
    # validate well-formed XML
    ET.fromstring(TWB)
    build = os.path.join(HERE, "_twbx_build")
    if os.path.exists(build):
        shutil.rmtree(build)
    os.makedirs(os.path.join(build, "Data"))
    with open(os.path.join(build, "PPR Scorecard.twb"), "w", encoding="utf-8") as f:
        f.write(TWB)
    shutil.copy(CSV, os.path.join(build, "Data", "ppr_scorecard_tidy.csv"))
    if os.path.exists(OUT_TWBX):
        os.remove(OUT_TWBX)
    with zipfile.ZipFile(OUT_TWBX, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(build, "PPR Scorecard.twb"), "PPR Scorecard.twb")
        z.write(os.path.join(build, "Data", "ppr_scorecard_tidy.csv"), "Data/ppr_scorecard_tidy.csv")
    shutil.rmtree(build)
    print(f"wrote {OUT_TWBX}  ({os.path.getsize(OUT_TWBX)//1024} KB)")
    print("XML well-formed:", True)

if __name__ == "__main__":
    main()
