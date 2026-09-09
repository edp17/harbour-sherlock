Name:       harbour-sherlock
Version:    1.0.0
Release:    0.0.0
Summary:    Sherlock logic deduction puzzle (6x6) for Sailfish OS
License:    GPL-3.0-or-later
Group:      Applications/Games
URL:        https://github.com/edp17/harbour-sherlock
Source0:    %{name}-%{version}.tar.bz2

BuildRequires: cmake
BuildRequires: pkgconfig(Qt5Core)
BuildRequires: pkgconfig(Qt5Gui)
BuildRequires: pkgconfig(Qt5Qml)
BuildRequires: pkgconfig(Qt5Quick)
BuildRequires: pkgconfig(sailfishapp)
BuildRequires: sailfishsilica-qt5-devel
BuildRequires: qt5-qttools-linguist

Requires: sailfishsilica-qt5

%description
A Sailfish OS implementation of the classic Sherlock 6x6 logic deduction puzzle.
Discovers selectable replacement-art themes from installed theme folders and
can also import sherlock.shi.

%prep
%setup -q

%build
%cmake .
%cmake_build

%install
%cmake_install

%files
%defattr(-,root,root,-)
%{_bindir}/harbour-sherlock
%{_datadir}/harbour-sherlock/
%{_datadir}/applications/harbour-sherlock.desktop
%{_datadir}/icons/hicolor/86x86/apps/harbour-sherlock.png
%{_datadir}/harbour-sherlock/qml/assets/puzzles/bank_4.txt
%{_datadir}/harbour-sherlock/qml/assets/puzzles/bank_5.txt
%{_datadir}/harbour-sherlock/qml/assets/puzzles/bank_6.txt
