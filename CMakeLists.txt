cmake_minimum_required(VERSION 3.10)
project(harbour-sherlock LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC OFF)
set(CMAKE_AUTOUIC OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt5 REQUIRED COMPONENTS Core Gui LinguistTools Qml Quick)

include(FindPkgConfig)
pkg_check_modules(SAILFISHAPP REQUIRED sailfishapp)

add_executable(harbour-sherlock
    src/main.cpp
    src/SherlockEngine.h
    src/SherlockEngine.cpp
    src/SherlockImageProvider.h
    src/SherlockImageProvider.cpp
    src/ShiReader.h
    src/ShiReader.cpp
    src/ClueSemantics.cpp
    src/ClueGenerator.cpp
    src/CandidateCompletion.cpp
    src/HintSolver.cpp
)

set(SHERLOCK_TRANSLATIONS
    translations/harbour-sherlock-hu.ts
)
qt5_add_translation(SHERLOCK_QM_FILES ${SHERLOCK_TRANSLATIONS})
add_custom_target(harbour-sherlock-translations ALL DEPENDS ${SHERLOCK_QM_FILES})
add_dependencies(harbour-sherlock harbour-sherlock-translations)

target_include_directories(harbour-sherlock PRIVATE
    ${SAILFISHAPP_INCLUDE_DIRS}
)

target_compile_options(harbour-sherlock PRIVATE
    ${SAILFISHAPP_CFLAGS_OTHER}
)

target_link_libraries(harbour-sherlock
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
    ${SAILFISHAPP_LIBRARIES}
)

option(SHERLOCK_BUILD_TESTS "Build deterministic clue-generator tests" OFF)
if(SHERLOCK_BUILD_TESTS)
    enable_testing()
    add_executable(test_cluegenerator
        src/ClueGenerator.cpp
        src/CandidateCompletion.cpp
        src/HintSolver.cpp
        tests/test_cluegenerator.cpp
    )
    target_include_directories(test_cluegenerator PRIVATE src)
    target_compile_definitions(test_cluegenerator PRIVATE
        SHERLOCK_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
    )
    add_test(NAME cluegenerator COMMAND test_cluegenerator)
endif()

install(TARGETS harbour-sherlock
    RUNTIME DESTINATION bin
)

# Main QML, excluding cover and assets (installed explicitly below)
install(DIRECTORY qml/
        DESTINATION share/${PROJECT_NAME}/qml
        FILES_MATCHING
        PATTERN "*.qml"
        PATTERN "assets" EXCLUDE
        PATTERN "cover" EXCLUDE
)

# Cover QML + any cover PNGs
install(DIRECTORY qml/cover/
        DESTINATION share/${PROJECT_NAME}/qml/cover
        FILES_MATCHING
        PATTERN "*.qml"
        PATTERN "*.png"
)

install(FILES harbour-sherlock.desktop
    DESTINATION share/applications
)

install(FILES icons/harbour-sherlock.png
    DESTINATION share/icons/hicolor/86x86/apps
)

# Cover icon used by CoverPage.qml as "icon.png"
install(FILES icons/harbour-sherlock.png
    DESTINATION share/${PROJECT_NAME}/qml/cover
    RENAME icon.png
)

# Installed icon theme assets and previews. Immediate subdirectories are
# discovered at runtime, so additional complete theme folders need no code
# changes.
install(DIRECTORY qml/assets/generated_icons/
        DESTINATION share/${PROJECT_NAME}/qml/assets/generated_icons
        FILES_MATCHING
        PATTERN "*.png"
)

# Puzzle assets (TXT)
install(DIRECTORY qml/assets/puzzles/
        DESTINATION share/${PROJECT_NAME}/qml/assets/puzzles
        FILES_MATCHING
        PATTERN "*.txt"
)

install(FILES ${SHERLOCK_QM_FILES}
    DESTINATION share/${PROJECT_NAME}/translations
)
