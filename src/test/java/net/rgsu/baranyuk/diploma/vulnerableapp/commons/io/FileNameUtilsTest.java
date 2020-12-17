package net.rgsu.baranyuk.diploma.vulnerableapp.commons.io;

import net.rgsu.baranyuk.diploma.vulnerableapp.BaseTest;
import org.apache.commons.io.FilenameUtils;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;

import java.io.File;
import java.io.IOException;

public class FileNameUtilsTest extends BaseTest {

    @Test
    @Disabled("Fixed in commons-io:2.7")
    void getPrefixLength() throws IOException {
        final String filename = "\\\\"+ System.getProperty("user.dir") + "\\tmp.txt";
        final int prefixLength = FilenameUtils.getPrefixLength(filename);
        Assertions.assertEquals(-1, prefixLength);
        if(prefixLength != -1) {
            Assertions.fail("File should not be created. Invalid host part is ignored.");
            //noinspection ResultOfMethodCallIgnored
            new File(filename).createNewFile();
        }
    }
}
