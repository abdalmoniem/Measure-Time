namespace JobApiLib
{
    using System;
    using System.Runtime.InteropServices;

    public class JobApi
    {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern IntPtr CreateJobObject(IntPtr securityAttributes, string jobName);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool AssignProcessToJobObject(IntPtr jobHandle, IntPtr processHandle);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool QueryInformationJobObject(IntPtr jobHandle, int infoClass, IntPtr infoBuffer, int bufferSize, out int returnLength);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CloseHandle(IntPtr objectHandle);

        [StructLayout(LayoutKind.Sequential)]
        public struct JobResourceUsage
        {
            public long TotalUserTime;
            public long TotalPrivilegedTime;
            public long ThisPeriodUserTime;
            public long ThisPeriodPrivilegedTime;
            public uint TotalTerminateProcessCounts;
            public uint TotalActiveProcessCounts;
            public uint TotalPausedProcessCounts;
        }

        public static int GetStructSize()
        {
            return Marshal.SizeOf(typeof(JobResourceUsage));
        }
    }
}