#!/usr/bin/env python3
# Regenerates themes/*.json from the Spunto design-system tokens (packages/design-system/styles.css
# of coderhammer/spunto, `cloud` product, converted from OKLCH to hex — VS Code takes nothing else).
# Run from this directory after a token change: python3 generate.py
import json
T = {
 "light": dict(bg="#f8fbf9", card="#fdfffe", sidebar="#f3f6f4", border="#dce1de", fg="#121b17", muted="#56605b",
   secondary="#eaeeeb", primary="#006737", primaryHover="#00552d", onPrimary="#f9fdfa", accent="#dff3e2", onAccent="#133c1f",
   field="#0a3423", signal="#bfeb56", onField="#e6f0e9", destructive="#e7000b", warning="#ec940d", success="#439d3b", info="#1c7abb",
   selection="#0067372e", lineHighlight="#0067370a", findMatch="#bfeb5699"),
 "dark": dict(bg="#0b0f0d", card="#121815", sidebar="#0f1412", border="#e3eae41c", fg="#ecf0ec", muted="#98a19c",
   secondary="#1f2623", primary="#bfeb56", primaryHover="#a9d43f", onPrimary="#0a3423", accent="#1c2e20", onAccent="#eaf0eb",
   field="#0a3423", signal="#bfeb56", onField="#d8e6dc", destructive="#ff6467", warning="#faab35", success="#65c36f", info="#4fa8e1",
   selection="#bfeb5633", lineHighlight="#bfeb560a", findMatch="#bfeb5659"),
}
def colors(c):
    return {
      "foreground": c["fg"], "descriptionForeground": c["muted"], "errorForeground": c["destructive"], "icon.foreground": c["muted"],
      "focusBorder": c["primary"], "widget.border": c["border"], "contrastBorder": None,
      "textLink.foreground": c["primary"], "textLink.activeForeground": c["primaryHover"],
      "progressBar.background": c["primary"],
      "editor.background": c["bg"], "editor.foreground": c["fg"],
      "editor.selectionBackground": c["selection"], "editor.inactiveSelectionBackground": c["lineHighlight"].replace("0a", "18"),
      "editor.lineHighlightBackground": c["lineHighlight"], "editor.lineHighlightBorder": "#00000000",
      "editor.findMatchHighlightBackground": c["findMatch"],
      "editorCursor.foreground": c["primary"], "editorLineNumber.foreground": c["muted"] + "99", "editorLineNumber.activeForeground": c["fg"],
      "editorIndentGuide.background1": c["border"], "editorIndentGuide.activeBackground1": c["muted"] + "66",
      "editorWidget.background": c["card"], "editorWidget.border": c["border"], "editorSuggestWidget.background": c["card"],
      "editorSuggestWidget.border": c["border"], "editorSuggestWidget.selectedBackground": c["accent"], "editorHoverWidget.background": c["card"],
      "editorHoverWidget.border": c["border"], "editorGroup.border": c["border"], "editorGroupHeader.tabsBackground": c["sidebar"],
      "editorGroupHeader.tabsBorder": c["border"], "editorOverviewRuler.border": c["border"],
      "editorGutter.addedBackground": c["success"], "editorGutter.modifiedBackground": c["info"], "editorGutter.deletedBackground": c["destructive"],
      "tab.activeBackground": c["bg"], "tab.activeForeground": c["fg"], "tab.activeBorderTop": c["primary"], "tab.activeBorder": c["bg"],
      "tab.inactiveBackground": c["sidebar"], "tab.inactiveForeground": c["muted"], "tab.border": c["border"], "tab.hoverBackground": c["bg"],
      "tab.unfocusedActiveBorderTop": c["border"], "tab.unfocusedHoverBackground": c["bg"], "tab.lastPinnedBorder": c["border"],
      "titleBar.activeBackground": c["sidebar"], "titleBar.activeForeground": c["fg"], "titleBar.inactiveBackground": c["sidebar"],
      "titleBar.inactiveForeground": c["muted"], "titleBar.border": c["border"],
      "activityBar.background": c["sidebar"], "activityBar.foreground": c["fg"], "activityBar.inactiveForeground": c["muted"],
      "activityBar.activeBorder": c["primary"], "activityBar.border": c["border"],
      "activityBarBadge.background": c["primary"], "activityBarBadge.foreground": c["onPrimary"],
      "sideBar.background": c["sidebar"], "sideBar.foreground": c["fg"], "sideBar.border": c["border"],
      "sideBarTitle.foreground": c["fg"], "sideBarSectionHeader.background": c["sidebar"], "sideBarSectionHeader.foreground": c["fg"],
      "sideBarSectionHeader.border": c["border"],
      "list.activeSelectionBackground": c["accent"], "list.activeSelectionForeground": c["onAccent"], "list.activeSelectionIconForeground": c["onAccent"],
      "list.inactiveSelectionBackground": c["accent"], "list.inactiveSelectionForeground": c["onAccent"], "list.hoverBackground": c["secondary"],
      "list.focusOutline": c["primary"], "list.focusAndSelectionOutline": c["primary"], "list.highlightForeground": c["primary"],
      "statusBar.background": c["field"], "statusBar.foreground": c["onField"], "statusBar.border": c["field"],
      "statusBar.noFolderBackground": c["field"], "statusBar.noFolderForeground": c["onField"],
      "statusBar.debuggingBackground": c["warning"], "statusBar.debuggingForeground": "#301904",
      "statusBarItem.remoteBackground": c["signal"], "statusBarItem.remoteForeground": c["field"],
      "statusBarItem.hoverBackground": "#ffffff1f", "statusBarItem.prominentBackground": c["signal"] + "33",
      "statusBarItem.errorBackground": c["destructive"],
      "panel.background": c["bg"], "panel.border": c["border"], "panelTitle.activeBorder": c["primary"],
      "panelTitle.activeForeground": c["fg"], "panelTitle.inactiveForeground": c["muted"], "panelInput.border": c["border"],
      "terminal.background": c["bg"], "terminal.foreground": c["fg"], "terminalCursor.foreground": c["primary"],
      "terminal.selectionBackground": c["selection"], "terminal.tab.activeBorder": c["primary"],
      "button.background": c["primary"], "button.foreground": c["onPrimary"], "button.hoverBackground": c["primaryHover"],
      "button.border": "#00000000", "button.secondaryBackground": c["secondary"], "button.secondaryForeground": c["fg"],
      "button.secondaryHoverBackground": c["border"],
      "badge.background": c["accent"], "badge.foreground": c["onAccent"],
      "input.background": c["card"], "input.foreground": c["fg"], "input.border": c["border"], "input.placeholderForeground": c["muted"],
      "inputOption.activeBackground": c["accent"], "inputOption.activeBorder": c["primary"], "inputOption.activeForeground": c["onAccent"],
      "dropdown.background": c["card"], "dropdown.border": c["border"], "dropdown.foreground": c["fg"], "dropdown.listBackground": c["card"],
      "checkbox.background": c["card"], "checkbox.border": c["border"],
      "quickInput.background": c["card"], "quickInput.foreground": c["fg"], "quickInputList.focusBackground": c["accent"],
      "quickInputList.focusForeground": c["onAccent"], "pickerGroup.foreground": c["primary"], "pickerGroup.border": c["border"],
      "menu.background": c["card"], "menu.foreground": c["fg"], "menu.border": c["border"], "menu.selectionBackground": c["accent"],
      "menu.selectionForeground": c["onAccent"],
      "notifications.background": c["card"], "notifications.foreground": c["fg"], "notifications.border": c["border"],
      "notificationCenterHeader.background": c["sidebar"], "notificationCenterHeader.foreground": c["fg"],
      "settings.headerForeground": c["fg"], "settings.modifiedItemIndicator": c["primary"],
      "welcomePage.tileBackground": c["card"], "welcomePage.tileBorder": c["border"],
      "textBlockQuote.background": c["sidebar"], "textBlockQuote.border": c["primary"], "textCodeBlock.background": c["secondary"],
      "textPreformat.background": c["secondary"], "textPreformat.foreground": c["fg"], "textSeparator.foreground": c["border"],
      "scrollbarSlider.background": c["muted"] + "33", "scrollbarSlider.hoverBackground": c["muted"] + "55", "scrollbarSlider.activeBackground": c["muted"] + "77",
      "gitDecoration.addedResourceForeground": c["success"], "gitDecoration.untrackedResourceForeground": c["success"],
      "gitDecoration.modifiedResourceForeground": c["info"], "gitDecoration.deletedResourceForeground": c["destructive"],
      "gitDecoration.conflictingResourceForeground": c["warning"],
      "ports.iconRunningProcessForeground": c["success"],
    }
base = {"light": "../../theme-defaults/themes/light_modern.json", "dark": "../../theme-defaults/themes/dark_modern.json"}
for k in ("light", "dark"):
    cols = {a: b for a, b in colors(T[k]).items() if b is not None}
    theme = {
      "$schema": "vscode://schemas/color-theme",
      "name": f"Spunto {k.capitalize()}",
      "type": k,
      # Syntax colours come from VS Code's own Modern theme; only the workbench is Spunto's.
      "include": base[k],
      "colors": dict(sorted(cols.items())),
    }
    json.dump(theme, open(f"themes/spunto-{k}-color-theme.json", "w"), indent=2)
    print(k, len(cols))
