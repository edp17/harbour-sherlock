Name:       harbour-sherlock
Version:    0.1.0
Release:    14
Summary:    Sherlock logic deduction puzzle (6x6) for Sailfish OS
License:    BSD-3-Clause
Group:      Applications/Games
URL:        https://example.invalid
Source0:    %{name}-%{version}.tar.bz2

BuildRequires: cmake
BuildRequires: pkgconfig(Qt5Core)
BuildRequires: pkgconfig(Qt5Gui)
BuildRequires: pkgconfig(Qt5Qml)
BuildRequires: pkgconfig(Qt5Quick)
BuildRequires: pkgconfig(sailfishapp)
BuildRequires: sailfishsilica-qt5-devel

Requires: sailfishsilica-qt5

%description
A Sailfish OS implementation of the classic Sherlock 6x6 logic deduction puzzle.
Does not ship original assets; user may import sherlock.shi.

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
