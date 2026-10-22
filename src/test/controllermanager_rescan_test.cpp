#include <gtest/gtest.h>

#include <QEventLoop>
#include <QFile>
#include <QTimer>

#include "controllers/controller.h"
#include "controllers/controllermanager.h"
#include "test/mixxxtest.h"

#if defined(Q_OS_MACOS) && defined(__PORTMIDI__)
#include <CoreMIDI/CoreMIDI.h>
#endif

class ControllerManagerRescanTest : public MixxxTest {};

TEST_F(ControllerManagerRescanTest, RepeatedRescanCompletes) {
    auto manager = std::make_shared<ControllerManager>(config());
    QEventLoop loop;
    QObject::connect(manager.get(), &ControllerManager::devicesChanged, &loop, &QEventLoop::quit);
    QTimer deadline;
    deadline.setSingleShot(true);
    QObject::connect(&deadline, &QTimer::timeout, &loop, &QEventLoop::quit);
    // Requests are queued to the same controller thread after initialization.
    for (int index = 0; index < 4; ++index) {
        deadline.start(5000);
        manager->rescanMidiDevices();
        loop.exec();
        ASSERT_TRUE(deadline.isActive()) << "MIDI rescan did not complete";
        deadline.stop();
    }
}

#if defined(Q_OS_MACOS) && defined(__PORTMIDI__)
TEST_F(ControllerManagerRescanTest, DiscoverRemoveAndRestoreEnabledCoreMidiSource) {
    const QString name = QStringLiteral("Mixxx Manual Rescan Test");
    const QString key = QStringLiteral("Mixxx_Manual_Rescan_Test");
    const QString mappingPath = getTestDataDir().filePath("rescan.midi.xml");
    QFile mapping(mappingPath);
    ASSERT_TRUE(mapping.open(QIODevice::WriteOnly));
    mapping.write(
            "<MixxxControllerPreset schemaVersion=\"1\"><info><name>Rescan Test</name></info>"
            "<controller id=\"Rescan Test\"><controls/><outputs/></controller>"
            "</MixxxControllerPreset>");
    mapping.close();
    config()->setValue(ConfigKey("[Controller]", key), 1);
    config()->setValue(ConfigKey("[ControllerPreset]", key), mappingPath);

    auto manager = std::make_shared<ControllerManager>(config());
    QEventLoop loop;
    QObject::connect(manager.get(), &ControllerManager::devicesChanged, &loop, &QEventLoop::quit);
    QTimer deadline;
    deadline.setSingleShot(true);
    QObject::connect(&deadline, &QTimer::timeout, &loop, &QEventLoop::quit);
    auto rescan = [&]() {
        deadline.start(5000);
        manager->rescanMidiDevices();
        loop.exec();
        const bool completed = deadline.isActive();
        deadline.stop();
        return completed;
    };
    auto findDevice = [&]() -> Controller* {
        for (auto* device : manager->getControllers()) {
            if (device->getName() == name) {
                return device;
            }
        }
        return nullptr;
    };
    ASSERT_TRUE(rescan());
    ASSERT_EQ(nullptr, findDevice());
    MIDIClientRef client = 0;
    ASSERT_EQ(noErr, MIDIClientCreate(CFSTR("Mixxx Rescan Test Client"), nullptr, nullptr, &client));
    // Dispose native endpoints even if a test assertion fails.
    struct NativeMidiScope {
        MIDIClientRef client;
        MIDIEndpointRef source = 0;
        ~NativeMidiScope() {
            if (source) {
                MIDIEndpointDispose(source);
            }
            MIDIClientDispose(client);
        }
    } native{client};
    ASSERT_EQ(noErr, MIDISourceCreate(client, CFSTR("Mixxx Manual Rescan Test"), &native.source));
    ASSERT_TRUE(rescan());
    ASSERT_NE(nullptr, findDevice());
    EXPECT_TRUE(findDevice()->isOpen());
    EXPECT_EQ(1, config()->getValue(ConfigKey("[Controller]", key), 0));
    // A second scan must reopen the configured mapping, not disable the device.
    ASSERT_TRUE(rescan());
    ASSERT_NE(nullptr, findDevice());
    EXPECT_TRUE(findDevice()->isOpen());
    ASSERT_EQ(noErr, MIDIEndpointDispose(native.source));
    native.source = 0;
    ASSERT_TRUE(rescan());
    EXPECT_EQ(nullptr, findDevice());
    EXPECT_EQ(1, config()->getValue(ConfigKey("[Controller]", key), 0));
    ASSERT_EQ(noErr, MIDISourceCreate(client, CFSTR("Mixxx Manual Rescan Test"), &native.source));
    ASSERT_TRUE(rescan());
    ASSERT_NE(nullptr, findDevice());
    EXPECT_TRUE(findDevice()->isOpen());
    manager.reset();
}
#endif
