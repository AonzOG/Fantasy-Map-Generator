# Fantasy Map Generator

## AonzOG's Fork - 04/10/2026

This fork keeps **Azgaar's Fantasy Map Generator** as the underlying project and adds two Windows convenience tools:

- 🛠️ **`Azgaar's Fantasy Map Generator.Bat`** — GUI installer, repair and uninstall tool
- ▶️ **`Start Azgaar's Fantasy Map Generator.Bat`** — one-click launcher for starting the installed generator

The aim is simple: **install and run the local version of Fantasy Map Generator with a few clicks instead of setting everything up manually through a terminal.**

### Few-Click Windows Installation

Double-click:

**`Azgaar's Fantasy Map Generator.Bat`**

This opens a Windows GUI setup wizard that guides you through installation.

### What the Installer Does

- 🖱️ **GUI installation wizard**
- 📁 **Lets you choose the installation directory**
- 🟢 **Automatically installs a local Node.js 24+ runtime**
- 🔐 **Verifies the Node.js download using SHA-256**
- 📦 **Automatically runs `npm install`**
- ▶️ **Creates a reusable local launcher**
- 🔧 **Repair installation**
- 🗑️ **Uninstall**
- 🗺️ **Preserves maps and common user assets during Repair**
- 🚫 **Does not install Node.js system-wide**

The repository, Node.js runtime and npm dependencies are kept together inside the selected installation folder.

When the installer is run from a downloaded copy of this fork, it can install from those existing repository files. If the required project files are unavailable, the installer can download the original upstream **Azgaar Fantasy Map Generator** repository.

The installer uses the local Node.js runtime to install the required npm dependencies and runs the generator through `npm run dev`.

### Starting the Generator

You will need to seperately download and copy the following file from this repo after installation (this is because the installer clones Azgaar's orignal repo, to stay up to date to any changes, not this fork, which only exists to archive Azgaar's repo as of 04/10/2026, apart from holding the installer and lancher files): 

**`Start Azgaar's Fantasy Map Generator.Bat`**

Simply Double-click it to launch the map generator.

The launcher:

- 🔎 Checks that the Fantasy Map Generator installation is present
- 🟢 Uses the locally installed Node.js runtime
- ▶️ Runs `npm run dev`
- 🌐 Opens the generator in your default browser (You can also copy and paste the local host address to open the map generator in any browser after launch)
- 🚫 Does not require a system-wide Node.js installation

Keep the launcher window open while using the generator. Closing it stops the local development server.

If the installation has been moved, damaged or is missing its local Node.js runtime, run **`Azgaar's Fantasy Map Generator.Bat`** again and choose **Repair**.

> **Install once. Start with a double-click afterwards.**

**Made to make things easy for me, now sharing to make things easy for you.**

### Vibe Code Alert

The AonzOG Windows installer and launcher were created with assistance from **GPT-5.6 Sol**.

They have **not** undergone an independent security audit or comprehensive static and dynamic cybersecurity assessment.

Both helper tools are plain-text Batch/PowerShell code, so you can inspect what they do before running them.

**The AonzOG Windows helper scripts are provided as-is and should be used at your own risk.**

### Licence

**Azgaar's Fantasy Map Generator** remains Azgaar's project and remains under its upstream **MIT licence**.

The AonzOG Windows helper files are separate additions to the fork.

**`Azgaar's Fantasy Map Generator.Bat`** and **Start Azgaar's Fantasy Map Generator.Bat** are released under **The Unlicense**. Feel free to use it, modify it, improve it or share it.

---

---

Azgaar's _Fantasy Map Generator_ is a free web application that helps fantasy writers, game masters, and cartographers create and edit fantasy maps.

Link: [azgaar.github.io/Fantasy-Map-Generator](https://azgaar.github.io/Fantasy-Map-Generator).

Refer to the [project wiki](https://github.com/Azgaar/Fantasy-Map-Generator/wiki) for guidance. Development is tracked on the [FMG dev board](https://github.com/users/Azgaar/projects/3). Some details are covered in my old blog [_Fantasy Maps for fun and glory_](https://azgaar.wordpress.com).

[![preview](https://github.com/Azgaar/Fantasy-Map-Generator/assets/26469650/9502eae9-92e0-4d0d-9f17-a2ba4a565c01)](https://github.com/Azgaar/Fantasy-Map-Generator/assets/26469650/11a42446-4bd5-4526-9cb1-3ef97c868992)

[![preview](https://github.com/Azgaar/Fantasy-Map-Generator/assets/26469650/e751a9e5-7986-4638-b8a9-362395ef7583)](https://github.com/Azgaar/Fantasy-Map-Generator/assets/26469650/e751a9e5-7986-4638-b8a9-362395ef7583)

[![preview](https://github.com/Azgaar/Fantasy-Map-Generator/assets/26469650/b0d0efde-a0d1-4e80-8818-ea3dd83c2323)](https://github.com/Azgaar/Fantasy-Map-Generator/assets/26469650/b0d0efde-a0d1-4e80-8818-ea3dd83c2323)

Join our [Discord server](https://discordapp.com/invite/X7E84HU) and [Reddit community](https://www.reddit.com/r/FantasyMapGenerator) to share your creations, discuss the Generator, suggest ideas and get the most recent updates.

Report bugs with the [bug report form](https://github.com/Azgaar/Fantasy-Map-Generator/issues/new?template=bug_report.yml), suggest features in [Ideas discussions](https://github.com/Azgaar/Fantasy-Map-Generator/discussions/categories/ideas), and ask usage questions in [Q&A](https://github.com/Azgaar/Fantasy-Map-Generator/discussions/categories/q-a). Search existing reports first. For bugs, include your FMG version, browser/OS, reproduction steps and an affected `.map` file in a ZIP archive when relevant. For ideas, explain the problem and your use case.

In Discord, use `#fmg-bugs` or `#fmg-suggestions`; the assistant's `/bug` and `/idea` commands, when available, open forms for moderator review before GitHub submission. Asking the assistant a question does not file a report. See [reporting instructions and examples](https://github.com/Azgaar/Fantasy-Map-Generator/wiki/Reporting-bugs-and-ideas).

Contact me via [email](mailto:azgaar.fmg@yandex.com) for non-public suggestions. For performance problems, first check the [performance tips](https://github.com/Azgaar/Fantasy-Map-Generator/wiki/Q&A#the-map-performance-is-poor-how-can-i-improve-it).

You can support the project on [Patreon](https://www.patreon.com/azgaar).

_Inspiration:_

- Martin O'Leary's [_Generating fantasy maps_](https://mewo2.com/notes/terrain)

- Amit Patel's [_Polygonal Map Generation for Games_](http://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation)

- Scott Turner's [_Here Dragons Abound_](https://heredragonsabound.blogspot.com)

## Desktop app

Installers for Linux, Windows and macOS are attached to each
[release](https://github.com/Azgaar/Fantasy-Map-Generator/releases). Nix users can build
the same app from the flake instead — see [Install with Nix](https://github.com/Azgaar/Fantasy-Map-Generator/wiki/Install-with-Nix):

```sh
nix run github:Azgaar/Fantasy-Map-Generator
```

## Contribution

Pull requests are highly welcomed. The codebase is messy and I will appreciate if you start with minor changes. Check out the [data model](https://github.com/Azgaar/Fantasy-Map-Generator/wiki/Data-model) before contributing.

The codebase is gradually transitioning from **vanilla JavaScript to TypeScript** while maintaining compatibility with the existing generation pipeline and old `.map` user files.

The expected **future** architecture is based on a separation between **world data**, **procedural generation**, **interactive editing**, and **rendering**. The application is conceptually divided into four main layers: world data and styles (state), generators (model), editors (controllers), renderers (view).

Flow:
settings → generators → world data → renderer
UI → editors → world data → renderer.

The data layer must contain no logic and no rendering code. Generators implement the procedural world simulation. Editors implement interactive editing tools used by the user. They perform controlled mutations of the world state. Editors can be viewed as interactive generators. The renderer converts the world state into SVG or WebGl graphics. Renderer must be pure visualization step and not modify world data.
