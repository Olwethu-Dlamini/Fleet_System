-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 17, 2026 at 09:42 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `vehicle_scheduling`
--

-- --------------------------------------------------------

--
-- Table structure for table `jobs`
--

CREATE TABLE `jobs` (
  `id` int(10) UNSIGNED NOT NULL,
  `job_number` varchar(50) NOT NULL COMMENT 'Human-readable job reference',
  `job_type` enum('installation','delivery','miscellaneous') NOT NULL,
  `customer_name` varchar(100) NOT NULL,
  `customer_phone` varchar(20) DEFAULT NULL,
  `customer_address` text NOT NULL,
  `description` text DEFAULT NULL,
  `scheduled_date` date NOT NULL,
  `scheduled_time_start` time NOT NULL,
  `scheduled_time_end` time NOT NULL,
  `estimated_duration_minutes` int(10) UNSIGNED NOT NULL COMMENT 'Expected job duration',
  `current_status` enum('pending','assigned','in_progress','completed','cancelled') NOT NULL DEFAULT 'pending',
  `priority` enum('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  `created_by` int(10) UNSIGNED NOT NULL COMMENT 'User who created the job',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data for table `jobs`
--

INSERT INTO `jobs` (`id`, `job_number`, `job_type`, `customer_name`, `customer_phone`, `customer_address`, `description`, `scheduled_date`, `scheduled_time_start`, `scheduled_time_end`, `estimated_duration_minutes`, `current_status`, `priority`, `created_by`, `created_at`, `updated_at`) VALUES
(1, 'JOB-2026-0001', 'installation', 'Ntombi Mngomezulu', '792968106', 'Unit 3, Nhlangano Civic Centre, Nhlangano', 'Set up new subscriber wireless connection. Install and aim outdoor unit, configure indoor router and run acceptance speed test.', '2026-03-03', '08:58:00', '11:28:00', 150, 'completed', 'low', 6, '2026-03-03 05:34:30', '2026-03-03 05:34:30'),
(2, 'JOB-2026-0002', 'installation', 'Buhle Lukhele', '773038096', 'Shop 3, Swazi Plaza, Mbabane', 'New fibre line installation at residential property. Run drop cable from street pole, install ONT and configure router for new subscriber.', '2026-03-03', '08:41:00', '11:41:00', 180, 'completed', 'normal', 25, '2026-03-03 05:03:53', '2026-03-03 05:03:53'),
(3, 'JOB-2026-0003', 'miscellaneous', 'Bongani Shabalala', '772597049', 'Shop 1, Siteki Plaza, Siteki', 'Underground cable damaged by nearby construction. Excavate affected section, repair and restore conduit protection.', '2026-03-03', '12:53:00', '16:53:00', 240, 'assigned', 'normal', 25, '2026-03-03 05:05:01', '2026-03-03 05:05:01'),
(4, 'JOB-2026-0004', 'miscellaneous', 'Thandi Shongwe', '782442154', 'Unit 4, Ngwane Street, Manzini', 'Pre-installation survey for new residential development. Assess cable routing options, identify splitter locations and document findings.', '2026-03-03', '08:00:00', '09:30:00', 90, 'in_progress', 'normal', 1, '2026-03-03 05:01:03', '2026-03-03 05:01:03'),
(5, 'JOB-2026-0005', 'miscellaneous', 'Lungelo Mthembu', '761315608', 'Unit 9, Club Road, Mbabane', 'Pre-installation survey for new residential development. Assess cable routing options, identify splitter locations and document findings.', '2026-03-03', '14:04:00', '15:34:00', 90, 'in_progress', 'high', 1, '2026-03-03 05:05:42', '2026-03-03 05:05:42'),
(6, 'JOB-2026-0006', 'miscellaneous', 'Mpendulo Khumalo', '779192645', 'Plot 33, Polinjane Road, Mbabane', 'Deliver demo router and CPE unit to prospective business client for trial period. Obtain signed loan agreement.', '2026-03-03', '14:38:00', '16:08:00', 90, 'completed', 'normal', 6, '2026-03-03 05:12:56', '2026-03-03 05:12:56'),
(7, 'JOB-2026-0007', 'delivery', 'Phiwayinkosi Mamba', '787032426', 'Unit 7, Industrial Road, Matsapha', 'Deliver hardware accompanying tender bid to Eswatini Communications Commission offices. Confirm receipt with procurement officer.', '2026-03-03', '10:25:00', '11:55:00', 90, 'in_progress', 'urgent', 25, '2026-03-03 05:03:13', '2026-03-03 05:03:13'),
(8, 'JOB-2026-0008', 'miscellaneous', 'Lindiwe Gumede', '792014660', 'Shop 6, Bhunu Mall, Manzini', 'Collect VIP client and transport to RealNet offices for account review meeting. Return client to premises after meeting.', '2026-03-04', '09:01:00', '10:31:00', 90, 'completed', 'high', 25, '2026-03-04 05:39:37', '2026-03-04 05:39:37'),
(9, 'JOB-2026-0009', 'installation', 'Sibusiso Nxumalo', '765390084', 'Plot 33, Polinjane Road, Mbabane', 'Install network infrastructure for new apartment complex. Configure managed switches and deploy wireless access points per floor.', '2026-03-04', '10:33:00', '14:33:00', 240, 'completed', 'high', 6, '2026-03-04 05:40:58', '2026-03-04 05:40:58'),
(10, 'JOB-2026-0010', 'installation', 'Langelihle Fakudze', '764551691', 'Unit 2, Lubombo Regional Office Park, Siteki', 'Install network infrastructure for new apartment complex. Configure managed switches and deploy wireless access points per floor.', '2026-03-04', '11:18:00', '15:18:00', 240, 'completed', 'high', 25, '2026-03-04 05:41:19', '2026-03-04 05:41:19'),
(11, 'JOB-2026-0011', 'miscellaneous', 'Mandla Dube', '772140331', 'Unit 3, Nhlangano Civic Centre, Nhlangano', 'Replace faulty PoE power injector for rooftop wireless equipment. Test equipment power-up and connectivity.', '2026-03-04', '09:37:00', '10:37:00', 60, 'completed', 'normal', 1, '2026-03-04 05:00:58', '2026-03-04 05:00:58'),
(12, 'JOB-2026-0012', 'miscellaneous', 'Thandi Shongwe', '766119115', 'Plot 19, Lavumisa Road, Nhlangano', 'Pre-installation survey for new residential development. Assess cable routing options, identify splitter locations and document findings.', '2026-03-04', '12:28:00', '13:58:00', 90, 'in_progress', 'urgent', 6, '2026-03-04 05:32:55', '2026-03-04 05:32:55'),
(13, 'JOB-2026-0013', 'installation', 'Mthokozisi Zwane', '798154135', 'Plot 21, Matsapha Industrial Estate, Matsapha', 'Set up new subscriber wireless connection. Install and aim outdoor unit, configure indoor router and run acceptance speed test.', '2026-03-04', '08:56:00', '11:26:00', 150, 'in_progress', 'high', 6, '2026-03-04 05:37:06', '2026-03-04 05:37:06'),
(14, 'JOB-2026-0014', 'miscellaneous', 'Ntsatsi Dlamini', '767203495', 'Plot 19, Lavumisa Road, Nhlangano', 'Drive sales team to corporate prospect presentation. Transport demonstration equipment and marketing materials.', '2026-03-04', '14:14:00', '15:44:00', 90, 'completed', 'normal', 25, '2026-03-04 05:31:14', '2026-03-04 05:31:14'),
(15, 'JOB-2026-0015', 'delivery', 'Zodwa Ngcamphalala', '791257067', 'Block C, Allister Miller Street, Mbabane', 'Deliver sealed tender documents and technical proposal to Ministry of ICT offices as per submission deadline requirements.', '2026-03-04', '15:04:00', '16:34:00', 90, 'cancelled', 'normal', 6, '2026-03-04 05:28:14', '2026-03-04 05:28:14'),
(16, 'JOB-2026-0016', 'miscellaneous', 'Swazi MTN Head Office', '775142588', 'Plot 21, Matsapha Industrial Estate, Matsapha', 'Survey business premises for WiFi coverage assessment. Map signal dead zones and recommend access point placement.', '2026-03-05', '14:03:00', '15:33:00', 90, 'cancelled', 'normal', 25, '2026-03-05 05:25:06', '2026-03-05 05:25:06'),
(17, 'JOB-2026-0017', 'installation', 'Sibonelo Msweli', '777381559', 'Block B, Swaziland Expo Site, Manzini', 'New internet installation for school. Run cabling through classrooms, install distribution switch and configure main router.', '2026-03-05', '08:07:00', '13:07:00', 300, 'cancelled', 'high', 1, '2026-03-05 05:12:13', '2026-03-05 05:12:13'),
(18, 'JOB-2026-0018', 'delivery', 'Langelihle Fakudze', '793444454', 'Plot 6, MR11 Road, Nhlangano', 'Deliver fibre ONT units and router stock to corporate client warehouse in Matsapha. Collect signed GRN.', '2026-03-05', '08:56:00', '10:56:00', 120, 'completed', 'urgent', 1, '2026-03-05 05:47:57', '2026-03-05 05:47:57'),
(19, 'JOB-2026-0019', 'miscellaneous', 'Sibonelo Msweli', '792250870', 'Unit 3, Nhlangano Civic Centre, Nhlangano', 'Conduct rooftop survey for planned wireless backhaul installation. Confirm line of sight to nearest tower and assess mounting options.', '2026-03-05', '11:28:00', '12:28:00', 60, 'completed', 'urgent', 6, '2026-03-05 05:27:20', '2026-03-05 05:27:20'),
(20, 'JOB-2026-0020', 'installation', 'Mfanafuthi Masuku', '784687071', 'Plot 6, MR11 Road, Nhlangano', 'New fibre line installation at residential property. Run drop cable from street pole, install ONT and configure router for new subscriber.', '2026-03-05', '10:36:00', '13:36:00', 180, 'completed', 'low', 6, '2026-03-05 05:02:27', '2026-03-05 05:02:27'),
(21, 'JOB-2026-0021', 'miscellaneous', 'Langelihle Fakudze', '768057707', 'Plot 14, Mhlumeni Road, Siteki', 'Survey school campus for network infrastructure upgrade. Document existing cabling, identify bottlenecks and propose improvements.', '2026-03-05', '13:19:00', '15:19:00', 120, 'completed', 'urgent', 25, '2026-03-05 05:55:36', '2026-03-05 05:55:36'),
(22, 'JOB-2026-0022', 'miscellaneous', 'Bongekile Sikhondze', '788098022', 'Plot 22, Msunduza Road, Mbabane', 'Client reports intermittent connectivity. Inspect router configuration, check line quality and run speed diagnostics.', '2026-03-06', '08:47:00', '10:17:00', 90, 'completed', 'normal', 6, '2026-03-06 05:11:02', '2026-03-06 05:11:02'),
(23, 'JOB-2026-0023', 'miscellaneous', 'Nomvula Nkosi', '769208701', 'Plot 55, Mhlakuvane Road, Manzini', 'Survey business premises for WiFi coverage assessment. Map signal dead zones and recommend access point placement.', '2026-03-06', '14:43:00', '16:13:00', 90, 'completed', 'urgent', 25, '2026-03-06 05:58:31', '2026-03-06 05:58:31'),
(24, 'JOB-2026-0024', 'installation', 'Lungelo Mthembu', '769040127', 'Unit 4, Ngwane Street, Manzini', 'New internet installation for school. Run cabling through classrooms, install distribution switch and configure main router.', '2026-03-06', '09:19:00', '14:19:00', 300, 'completed', 'normal', 1, '2026-03-06 05:16:16', '2026-03-06 05:16:16'),
(25, 'JOB-2026-0025', 'miscellaneous', 'Mthunzi Hhohho', '774982797', 'Plot 11, King Sobhuza II Avenue, Nhlangano', 'Swap defective managed switch at business client. Restore VLAN configuration and verify all ports operational.', '2026-03-06', '13:58:00', '15:28:00', 90, 'completed', 'normal', 1, '2026-03-06 05:19:43', '2026-03-06 05:19:43'),
(26, 'JOB-2026-0026', 'miscellaneous', 'Lindiwe Gumede', '783232888', 'Plot 22, Msunduza Road, Mbabane', 'Deliver trial internet equipment to new business lead for evaluation. Install, configure and brief client on usage.', '2026-03-06', '08:55:00', '10:55:00', 120, 'completed', 'normal', 25, '2026-03-06 05:43:13', '2026-03-06 05:43:13'),
(27, 'JOB-2026-0027', 'delivery', 'Swazi MTN Head Office', '782738233', 'Plot 6, MR11 Road, Nhlangano', 'Deliver ordered network hardware including switches, routers and patch panels to client site. Obtain signed delivery note.', '2026-03-06', '14:55:00', '16:55:00', 120, 'completed', 'normal', 6, '2026-03-06 05:04:58', '2026-03-06 05:04:58'),
(28, 'JOB-2026-0028', 'miscellaneous', 'Zodwa Ngcamphalala', '779984602', 'Shop 2, Nhlangano Shopping Centre, Nhlangano', 'Subscriber reporting speeds below subscribed plan. Check router QoS settings, run speed test and escalate if line fault found.', '2026-03-06', '11:14:00', '12:44:00', 90, 'completed', 'normal', 1, '2026-03-06 05:27:24', '2026-03-06 05:27:24'),
(29, 'JOB-2026-0029', 'miscellaneous', 'Tibiyo TakaNgwane', '769008243', 'Plot 22, MR14 Road, Siteki', 'Replace end-of-life outdoor CPE unit. Remount new unit, reconfigure wireless settings and run throughput test.', '2026-03-09', '10:22:00', '12:22:00', 120, 'in_progress', 'normal', 1, '2026-03-09 05:45:54', '2026-03-09 05:45:54'),
(30, 'JOB-2026-0030', 'installation', 'Themba Dlamini', '775898193', 'Plot 14, Mhlumeni Road, Siteki', 'Set up new subscriber wireless connection. Install and aim outdoor unit, configure indoor router and run acceptance speed test.', '2026-03-09', '10:50:00', '13:20:00', 150, 'completed', 'high', 25, '2026-03-09 05:22:15', '2026-03-09 05:22:15'),
(31, 'JOB-2026-0031', 'miscellaneous', 'Bongekile Sikhondze', '764070287', 'Plot 8, Siteki Main Road, Siteki', 'Client reports intermittent connectivity. Inspect router configuration, check line quality and run speed diagnostics.', '2026-03-09', '09:42:00', '11:12:00', 90, 'completed', 'high', 6, '2026-03-09 05:46:22', '2026-03-09 05:46:22'),
(32, 'JOB-2026-0032', 'delivery', 'Mandla Dube', '781244336', 'Block C, Allister Miller Street, Mbabane', 'Deliver hardware accompanying tender bid to Eswatini Communications Commission offices. Confirm receipt with procurement officer.', '2026-03-09', '15:08:00', '16:38:00', 90, 'completed', 'normal', 1, '2026-03-09 05:03:59', '2026-03-09 05:03:59'),
(33, 'JOB-2026-0033', 'miscellaneous', 'Phiwayinkosi Mamba', '772918401', 'Plot 22, Msunduza Road, Mbabane', 'Conduct rooftop survey for planned wireless backhaul installation. Confirm line of sight to nearest tower and assess mounting options.', '2026-03-09', '12:41:00', '13:41:00', 60, 'completed', 'high', 6, '2026-03-09 05:43:31', '2026-03-09 05:43:31'),
(34, 'JOB-2026-0034', 'miscellaneous', 'Sifiso Hlophe', '766578138', 'Unit 15, Tex Ray Industrial Park, Matsapha', 'Accompany sales representative to client site using company vehicle. Support product demonstration and collect signed quote.', '2026-03-09', '12:34:00', '14:34:00', 120, 'cancelled', 'urgent', 1, '2026-03-09 05:42:19', '2026-03-09 05:42:19'),
(35, 'JOB-2026-0035', 'miscellaneous', 'Mfanafuthi Masuku', '763937212', 'Plot 3, Mancishane Road, Manzini', 'Client reports intermittent connectivity. Inspect router configuration, check line quality and run speed diagnostics.', '2026-03-09', '14:04:00', '15:34:00', 90, 'completed', 'normal', 25, '2026-03-09 05:03:16', '2026-03-09 05:03:16'),
(36, 'JOB-2026-0036', 'miscellaneous', 'Khulekani Magagula', '761152740', 'Plot 11, King Sobhuza II Avenue, Nhlangano', 'Swap faulty ONT unit at subscriber premises with replacement stock. Reconfigure settings and confirm full service restoration.', '2026-03-09', '14:44:00', '16:14:00', 90, 'completed', 'high', 1, '2026-03-09 05:29:48', '2026-03-09 05:29:48'),
(37, 'JOB-2026-0037', 'delivery', 'Lungelo Mthembu', '796668041', 'Block B, Swaziland Expo Site, Manzini', 'Deliver server rack components and structured cabling materials to government ICT department. Verify quantities on delivery note.', '2026-03-09', '08:23:00', '10:23:00', 120, 'in_progress', 'high', 25, '2026-03-09 05:39:08', '2026-03-09 05:39:08'),
(38, 'JOB-2026-0038', 'installation', 'Langelihle Fakudze', '795746754', 'Unit 2, Lubombo Regional Office Park, Siteki', 'Fibre to the business installation. Lay internal cabling, terminate patch panel and configure managed router.', '2026-03-10', '08:12:00', '12:12:00', 240, 'completed', 'normal', 25, '2026-03-10 05:29:26', '2026-03-10 05:29:26'),
(39, 'JOB-2026-0039', 'installation', 'Sibonelo Msweli', '788508087', 'Warehouse 3, Matsapha Airport Road, Matsapha', 'Install new wireless point-to-point link between two office buildings. Align dishes and configure IP settings.', '2026-03-10', '08:04:00', '12:04:00', 240, 'cancelled', 'high', 6, '2026-03-10 05:39:08', '2026-03-10 05:39:08'),
(40, 'JOB-2026-0040', 'delivery', 'Lungisa Mavuso', '781044845', 'Warehouse 3, Matsapha Airport Road, Matsapha', 'Deliver spare CPE units, cable reels and splicing materials to field technician team in Siteki.', '2026-03-10', '08:01:00', '09:31:00', 90, 'cancelled', 'normal', 25, '2026-03-10 05:07:07', '2026-03-10 05:07:07'),
(41, 'JOB-2026-0041', 'installation', 'Phumzile Matsenjwa', '765509042', 'Unit 12, Sandlane Street, Manzini', 'Install wireless internet equipment at business premises. Mount outdoor antenna on rooftop, configure CPE and test signal strength.', '2026-03-10', '11:09:00', '14:09:00', 180, 'cancelled', 'normal', 6, '2026-03-10 05:44:58', '2026-03-10 05:44:58'),
(42, 'JOB-2026-0042', 'delivery', 'Nomvula Nkosi', '767160676', 'Shop 1, Siteki Plaza, Siteki', 'Deliver server rack components and structured cabling materials to government ICT department. Verify quantities on delivery note.', '2026-03-10', '14:42:00', '16:42:00', 120, 'completed', 'normal', 6, '2026-03-10 05:30:26', '2026-03-10 05:30:26'),
(43, 'JOB-2026-0043', 'delivery', 'Muzi Mahlalela', '781238398', 'Unit 15, Tex Ray Industrial Park, Matsapha', 'Deliver hardware accompanying tender bid to Eswatini Communications Commission offices. Confirm receipt with procurement officer.', '2026-03-10', '14:00:00', '15:30:00', 90, 'in_progress', 'low', 1, '2026-03-10 05:20:31', '2026-03-10 05:20:31'),
(44, 'JOB-2026-0044', 'miscellaneous', 'Lindiwe Gumede', '764887355', 'Plot 3, Mancishane Road, Manzini', 'Deliver demo router and CPE unit to prospective business client for trial period. Obtain signed loan agreement.', '2026-03-10', '15:00:00', '16:30:00', 90, 'in_progress', 'high', 6, '2026-03-10 05:43:43', '2026-03-10 05:43:43'),
(45, 'JOB-2026-0045', 'miscellaneous', 'Buhle Lukhele', '772257139', 'Unit 7, Industrial Road, Matsapha', 'Repair damaged patch panel port. Re-terminate cable, test continuity and confirm throughput restored.', '2026-03-10', '09:31:00', '10:31:00', 60, 'assigned', 'high', 1, '2026-03-10 05:20:00', '2026-03-10 05:20:00'),
(46, 'JOB-2026-0046', 'miscellaneous', 'Zodwa Ngcamphalala', '793953060', 'Plot 3, Mancishane Road, Manzini', 'Conduct rooftop survey for planned wireless backhaul installation. Confirm line of sight to nearest tower and assess mounting options.', '2026-03-11', '10:51:00', '11:51:00', 60, 'completed', 'normal', 25, '2026-03-11 05:52:48', '2026-03-11 05:52:48'),
(47, 'JOB-2026-0047', 'delivery', 'Mandla Dube', '795774214', 'Plot 8, Siteki Main Road, Siteki', 'Deliver ordered network hardware including switches, routers and patch panels to client site. Obtain signed delivery note.', '2026-03-11', '09:24:00', '11:24:00', 120, 'completed', 'normal', 1, '2026-03-11 05:03:26', '2026-03-11 05:03:26'),
(48, 'JOB-2026-0048', 'miscellaneous', 'Mpendulo Khumalo', '795970964', 'Plot 55, Mhlakuvane Road, Manzini', 'Router rebooting randomly at business premises. Check firmware version, inspect power supply and update configuration.', '2026-03-11', '13:44:00', '15:14:00', 90, 'completed', 'normal', 25, '2026-03-11 05:24:07', '2026-03-11 05:24:07'),
(49, 'JOB-2026-0049', 'installation', 'Phumzile Matsenjwa', '768832920', 'Unit 15, Tex Ray Industrial Park, Matsapha', 'New fibre line installation at residential property. Run drop cable from street pole, install ONT and configure router for new subscriber.', '2026-03-11', '10:48:00', '13:48:00', 180, 'cancelled', 'urgent', 25, '2026-03-11 05:28:38', '2026-03-11 05:28:38'),
(50, 'JOB-2026-0050', 'miscellaneous', 'Ntombi Mngomezulu', '762804765', 'Unit 4, Ngwane Street, Manzini', 'Client reports intermittent connectivity. Inspect router configuration, check line quality and run speed diagnostics.', '2026-03-11', '15:16:00', '16:46:00', 90, 'completed', 'normal', 25, '2026-03-11 05:54:51', '2026-03-11 05:54:51'),
(51, 'JOB-2026-0051', 'miscellaneous', 'Nokukhanya Vilakati', '769934657', 'Plot 7, Hospital Hill, Mbabane', 'Swap defective managed switch at business client. Restore VLAN configuration and verify all ports operational.', '2026-03-11', '09:14:00', '10:44:00', 90, 'in_progress', 'low', 25, '2026-03-11 05:37:32', '2026-03-11 05:37:32'),
(52, 'JOB-2026-0052', 'miscellaneous', 'Sipho Maseko', '795575914', 'Shop 1, Siteki Plaza, Siteki', 'Replace faulty PoE power injector for rooftop wireless equipment. Test equipment power-up and connectivity.', '2026-03-12', '11:26:00', '12:26:00', 60, 'completed', 'normal', 1, '2026-03-12 05:17:38', '2026-03-12 05:17:38'),
(53, 'JOB-2026-0053', 'miscellaneous', 'Siyanda Motsa', '788113690', 'Unit 15, Tex Ray Industrial Park, Matsapha', 'Router rebooting randomly at business premises. Check firmware version, inspect power supply and update configuration.', '2026-03-12', '13:44:00', '15:14:00', 90, 'cancelled', 'high', 1, '2026-03-12 05:03:10', '2026-03-12 05:03:10'),
(54, 'JOB-2026-0054', 'miscellaneous', 'Muzi Mahlalela', '783667783', 'Unit 12, Sandlane Street, Manzini', 'Overhead drop cable sagging between poles causing signal loss. Re-tension, secure and test link stability.', '2026-03-12', '09:12:00', '11:12:00', 120, 'completed', 'normal', 1, '2026-03-12 05:31:38', '2026-03-12 05:31:38'),
(55, 'JOB-2026-0055', 'miscellaneous', 'Phila Gamedze', '788410950', 'Plot 9, Ngwempisi Road, Matsapha', 'Overhead drop cable sagging between poles causing signal loss. Re-tension, secure and test link stability.', '2026-03-12', '08:29:00', '10:29:00', 120, 'completed', 'urgent', 25, '2026-03-12 05:47:33', '2026-03-12 05:47:33'),
(56, 'JOB-2026-0056', 'installation', 'Nokwanda Tfwala', '767803677', 'Plot 18, Louw Street, Manzini', 'Install network infrastructure for new apartment complex. Configure managed switches and deploy wireless access points per floor.', '2026-03-13', '09:06:00', '13:06:00', 240, 'cancelled', 'normal', 25, '2026-03-13 05:41:31', '2026-03-13 05:41:31'),
(57, 'JOB-2026-0057', 'delivery', 'Phiwayinkosi Mamba', '766382625', 'Plot 21, Matsapha Industrial Estate, Matsapha', 'Deliver spare CPE units, cable reels and splicing materials to field technician team in Siteki.', '2026-03-13', '14:51:00', '16:21:00', 90, 'completed', 'high', 1, '2026-03-13 05:20:33', '2026-03-13 05:20:33'),
(58, 'JOB-2026-0058', 'installation', 'Thandeka Mnisi', '761576160', 'Unit 3, Nhlangano Civic Centre, Nhlangano', 'Install wireless internet equipment at business premises. Mount outdoor antenna on rooftop, configure CPE and test signal strength.', '2026-03-13', '13:56:00', '16:56:00', 180, 'completed', 'normal', 1, '2026-03-13 05:23:03', '2026-03-13 05:23:03'),
(59, 'JOB-2026-0059', 'miscellaneous', 'Phumzile Matsenjwa', '798473758', 'Shop 2, Nhlangano Shopping Centre, Nhlangano', 'Collect VIP client and transport to RealNet offices for account review meeting. Return client to premises after meeting.', '2026-03-13', '08:55:00', '10:25:00', 90, 'completed', 'normal', 25, '2026-03-13 05:00:55', '2026-03-13 05:00:55'),
(60, 'JOB-2026-0060', 'delivery', 'Ntombi Mngomezulu', '799506532', 'Block C, Allister Miller Street, Mbabane', 'Deliver ordered network hardware including switches, routers and patch panels to client site. Obtain signed delivery note.', '2026-03-13', '13:56:00', '15:56:00', 120, 'assigned', 'low', 25, '2026-03-13 05:35:31', '2026-03-13 05:35:31'),
(61, 'JOB-2026-0061', 'installation', 'Lindiwe Gumede', '767856275', 'Plot 6, MR11 Road, Nhlangano', 'Install network infrastructure for new apartment complex. Configure managed switches and deploy wireless access points per floor.', '2026-03-13', '09:23:00', '13:23:00', 240, 'completed', 'urgent', 6, '2026-03-13 05:47:06', '2026-03-13 05:47:06'),
(62, 'JOB-2026-0062', 'installation', 'Mthunzi Hhohho', '795705113', 'Unit 9, Club Road, Mbabane', 'Install wireless internet equipment at business premises. Mount outdoor antenna on rooftop, configure CPE and test signal strength.', '2026-03-13', '10:45:00', '13:45:00', 180, 'completed', 'normal', 1, '2026-03-13 05:52:41', '2026-03-13 05:52:41'),
(63, 'JOB-2026-0063', 'installation', 'Thandi Shongwe', '779125730', 'Block C, Allister Miller Street, Mbabane', 'New internet installation for school. Run cabling through classrooms, install distribution switch and configure main router.', '2026-03-16', '08:35:00', '13:35:00', 300, 'in_progress', 'normal', 6, '2026-03-16 05:37:18', '2026-03-16 05:37:18'),
(64, 'JOB-2026-0064', 'delivery', 'Sibusiso Nxumalo', '787394024', 'Warehouse 3, Matsapha Airport Road, Matsapha', 'Deliver ordered network hardware including switches, routers and patch panels to client site. Obtain signed delivery note.', '2026-03-16', '14:49:00', '16:49:00', 120, 'completed', 'normal', 1, '2026-03-16 05:35:50', '2026-03-16 05:35:50'),
(65, 'JOB-2026-0065', 'installation', 'Lindiwe Gumede', '763982437', 'Plot 8, Siteki Main Road, Siteki', 'Fibre to the business installation. Lay internal cabling, terminate patch panel and configure managed router.', '2026-03-16', '08:13:00', '12:13:00', 240, 'in_progress', 'high', 1, '2026-03-16 05:59:00', '2026-03-16 05:59:00'),
(66, 'JOB-2026-0066', 'miscellaneous', 'Nompumelelo Simelane', '778594832', 'Plot 55, Mhlakuvane Road, Manzini', 'Subscriber reporting speeds below subscribed plan. Check router QoS settings, run speed test and escalate if line fault found.', '2026-03-16', '09:20:00', '10:50:00', 90, 'cancelled', 'normal', 6, '2026-03-16 05:46:02', '2026-03-16 05:46:02'),
(67, 'JOB-2026-0067', 'installation', 'RealNet Government Tender Office', '767328332', 'Unit 4, Ngwane Street, Manzini', 'Install network infrastructure for new apartment complex. Configure managed switches and deploy wireless access points per floor.', '2026-03-16', '11:23:00', '15:23:00', 240, 'completed', 'normal', 6, '2026-03-16 05:46:59', '2026-03-16 05:46:59'),
(68, 'JOB-2026-0068', 'installation', 'Mthokozisi Zwane', '787790920', 'Warehouse 3, Matsapha Airport Road, Matsapha', 'Set up new subscriber wireless connection. Install and aim outdoor unit, configure indoor router and run acceptance speed test.', '2026-03-16', '13:31:00', '16:01:00', 150, 'completed', 'normal', 6, '2026-03-16 05:35:46', '2026-03-16 05:35:46'),
(69, 'JOB-2026-0069', 'delivery', 'Thandi Shongwe', '781215361', 'Plot 22, MR14 Road, Siteki', 'Deliver hardware accompanying tender bid to Eswatini Communications Commission offices. Confirm receipt with procurement officer.', '2026-03-16', '15:24:00', '16:54:00', 90, 'completed', 'urgent', 6, '2026-03-16 05:38:40', '2026-03-16 05:38:40'),
(70, 'JOB-2026-0070', 'miscellaneous', 'Sibonelo Msweli', '792985042', 'Plot 6, MR11 Road, Nhlangano', 'Replace faulty PoE power injector for rooftop wireless equipment. Test equipment power-up and connectivity.', '2026-03-16', '12:15:00', '13:15:00', 60, 'completed', 'normal', 25, '2026-03-16 05:44:46', '2026-03-16 05:44:46'),
(71, 'JOB-2026-0071', 'miscellaneous', 'Mthunzi Hhohho', '797863789', 'Unit 9, Club Road, Mbabane', 'Underground cable damaged by nearby construction. Excavate affected section, repair and restore conduit protection.', '2026-03-17', '11:38:00', '15:38:00', 240, 'completed', 'normal', 1, '2026-03-17 05:37:37', '2026-03-17 05:37:37'),
(72, 'JOB-2026-0072', 'installation', 'Sithembile Bhembe', '794460019', 'Unit 2, Lubombo Regional Office Park, Siteki', 'New fibre line installation at residential property. Run drop cable from street pole, install ONT and configure router for new subscriber.', '2026-03-17', '13:52:00', '16:52:00', 180, 'in_progress', 'urgent', 1, '2026-03-17 05:14:04', '2026-03-17 05:14:04'),
(73, 'JOB-2026-0073', 'delivery', 'Muzi Mahlalela', '772113440', 'Unit 12, Sandlane Street, Manzini', 'Deliver ordered network hardware including switches, routers and patch panels to client site. Obtain signed delivery note.', '2026-03-17', '10:25:00', '12:25:00', 120, 'completed', 'low', 25, '2026-03-17 05:14:06', '2026-03-17 05:14:06'),
(74, 'JOB-2026-0074', 'delivery', 'Sifiso Hlophe', '782136080', 'Plot 14, Gwamile Street, Mbabane', 'Deliver spare CPE units, cable reels and splicing materials to field technician team in Siteki.', '2026-03-17', '15:09:00', '16:39:00', 90, 'completed', 'normal', 6, '2026-03-17 05:52:54', '2026-03-17 05:52:54'),
(75, 'JOB-2026-0075', 'delivery', 'Themba Dlamini', '775426876', 'Plot 22, MR14 Road, Siteki', 'Deliver fibre ONT units and router stock to corporate client warehouse in Matsapha. Collect signed GRN.', '2026-03-17', '12:13:00', '14:13:00', 120, 'completed', 'normal', 25, '2026-03-17 05:54:00', '2026-03-17 05:54:00'),
(76, 'JOB-2026-0076', 'installation', 'Mpendulo Khumalo', '781137657', 'Plot 55, Mhlakuvane Road, Manzini', 'New fibre line installation at residential property. Run drop cable from street pole, install ONT and configure router for new subscriber.', '2026-03-17', '08:11:00', '11:11:00', 180, 'completed', 'normal', 1, '2026-03-17 05:39:02', '2026-03-17 05:39:02'),
(77, 'JOB-2026-0077', 'miscellaneous', 'Tibiyo TakaNgwane', '795345965', 'Plot 22, MR14 Road, Siteki', 'Survey business premises for WiFi coverage assessment. Map signal dead zones and recommend access point placement.', '2026-03-17', '08:40:00', '10:10:00', 90, 'cancelled', 'normal', 1, '2026-03-17 05:46:56', '2026-03-17 05:46:56'),
(78, 'JOB-2026-0078', 'miscellaneous', 'Ntombi Mngomezulu', '785763731', 'Plot 14, Mhlumeni Road, Siteki', 'Pre-installation survey for new residential development. Assess cable routing options, identify splitter locations and document findings.', '2026-03-17', '10:12:00', '11:42:00', 90, 'completed', 'normal', 1, '2026-03-17 05:24:57', '2026-03-17 05:24:57'),
(79, 'JOB-2026-0079', 'miscellaneous', 'Lungisa Mavuso', '766872952', 'Plot 19, Lavumisa Road, Nhlangano', 'Survey business premises for WiFi coverage assessment. Map signal dead zones and recommend access point placement.', '2026-03-18', '14:57:00', '16:27:00', 90, 'assigned', 'high', 25, '2026-03-18 05:22:08', '2026-03-18 05:22:08'),
(80, 'JOB-2026-0080', 'installation', 'Langelihle Fakudze', '785354102', 'Plot 14, Mhlumeni Road, Siteki', 'Install network infrastructure for new apartment complex. Configure managed switches and deploy wireless access points per floor.', '2026-03-18', '11:07:00', '15:07:00', 240, 'assigned', 'normal', 1, '2026-03-18 05:04:30', '2026-03-18 05:04:30'),
(81, 'JOB-2026-0081', 'miscellaneous', 'Phiwayinkosi Mamba', '778459245', 'Plot 55, Mhlakuvane Road, Manzini', 'Underground cable damaged by nearby construction. Excavate affected section, repair and restore conduit protection.', '2026-03-18', '12:07:00', '16:07:00', 240, 'assigned', 'high', 1, '2026-03-18 05:59:20', '2026-03-18 05:59:20'),
(82, 'JOB-2026-0082', 'delivery', 'Nompumelelo Simelane', '781679369', 'Plot 14, Gwamile Street, Mbabane', 'Deliver spare CPE units, cable reels and splicing materials to field technician team in Siteki.', '2026-03-18', '10:57:00', '12:27:00', 90, 'assigned', 'normal', 6, '2026-03-18 05:25:42', '2026-03-18 05:25:42'),
(83, 'JOB-2026-0083', 'delivery', 'Phiwayinkosi Mamba', '773909180', 'Unit 15, Tex Ray Industrial Park, Matsapha', 'Deliver sealed tender documents and technical proposal to Ministry of ICT offices as per submission deadline requirements.', '2026-03-18', '12:28:00', '13:58:00', 90, 'assigned', 'high', 6, '2026-03-18 05:27:43', '2026-03-18 05:27:43'),
(84, 'JOB-2026-0084', 'delivery', 'Sibusiso Nxumalo', '767481036', 'Plot 22, MR14 Road, Siteki', 'Deliver spare CPE units, cable reels and splicing materials to field technician team in Siteki.', '2026-03-18', '10:35:00', '12:05:00', 90, 'assigned', 'urgent', 25, '2026-03-18 05:22:14', '2026-03-18 05:22:14'),
(85, 'JOB-2026-0085', 'miscellaneous', 'Swazi MTN Head Office', '793024765', 'Shop 3, Swazi Plaza, Mbabane', 'Replace faulty PoE power injector for rooftop wireless equipment. Test equipment power-up and connectivity.', '2026-03-18', '15:08:00', '16:08:00', 60, 'assigned', 'urgent', 1, '2026-03-18 05:06:26', '2026-03-18 05:06:26'),
(86, 'JOB-2026-0086', 'miscellaneous', 'Sibonelo Msweli', '782070106', 'Plot 14, Gwamile Street, Mbabane', 'Conduct rooftop survey for planned wireless backhaul installation. Confirm line of sight to nearest tower and assess mounting options.', '2026-03-18', '09:56:00', '10:56:00', 60, 'assigned', 'urgent', 1, '2026-03-18 05:49:07', '2026-03-18 05:49:07'),
(87, 'JOB-2026-0087', 'installation', 'Mthunzi Hhohho', '791102639', 'Unit 12, Sandlane Street, Manzini', 'Set up new subscriber wireless connection. Install and aim outdoor unit, configure indoor router and run acceptance speed test.', '2026-03-19', '10:51:00', '13:21:00', 150, 'assigned', 'normal', 25, '2026-03-19 05:31:44', '2026-03-19 05:31:44'),
(88, 'JOB-2026-0088', 'miscellaneous', 'Thandeka Mnisi', '793908927', 'Unit 2, Lubombo Regional Office Park, Siteki', 'Subscriber reporting speeds below subscribed plan. Check router QoS settings, run speed test and escalate if line fault found.', '2026-03-19', '11:19:00', '12:49:00', 90, 'assigned', 'high', 1, '2026-03-19 05:23:34', '2026-03-19 05:23:34'),
(89, 'JOB-2026-0089', 'miscellaneous', 'Lindiwe Gumede', '789703065', 'Unit 4, Ngwane Street, Manzini', 'Underground cable damaged by nearby construction. Excavate affected section, repair and restore conduit protection.', '2026-03-19', '09:13:00', '13:13:00', 240, 'assigned', 'low', 25, '2026-03-19 05:50:55', '2026-03-19 05:50:55'),
(90, 'JOB-2026-0090', 'miscellaneous', 'Mthunzi Hhohho', '776796022', 'Plot 14, Mhlumeni Road, Siteki', 'Rodent damage to indoor patch cable reported. Replace chewed section, retest service and advise client on cable management.', '2026-03-19', '09:09:00', '10:09:00', 60, 'assigned', 'normal', 25, '2026-03-19 05:05:03', '2026-03-19 05:05:03'),
(91, 'JOB-2026-0091', 'delivery', 'Swazi MTN Head Office', '774665014', 'Shop 6, Bhunu Mall, Manzini', 'Deliver spare CPE units, cable reels and splicing materials to field technician team in Siteki.', '2026-03-19', '09:48:00', '11:18:00', 90, 'assigned', 'low', 25, '2026-03-19 05:47:16', '2026-03-19 05:47:16'),
(92, 'JOB-2026-0092', 'delivery', 'Themba Dlamini', '791131643', 'Shop 6, Bhunu Mall, Manzini', 'Deliver hardware accompanying tender bid to Eswatini Communications Commission offices. Confirm receipt with procurement officer.', '2026-03-19', '13:58:00', '15:28:00', 90, 'assigned', 'normal', 6, '2026-03-19 05:27:14', '2026-03-19 05:27:14'),
(93, 'JOB-2026-0093', 'installation', 'RealNet Government Tender Office', '794845609', 'Plot 3, Mancishane Road, Manzini', 'Fibre to the business installation. Lay internal cabling, terminate patch panel and configure managed router.', '2026-03-20', '10:28:00', '14:28:00', 240, 'assigned', 'normal', 25, '2026-03-20 05:03:53', '2026-03-20 05:03:53'),
(94, 'JOB-2026-0094', 'installation', 'Siyanda Motsa', '793505206', 'Unit 9, Club Road, Mbabane', 'New internet installation for school. Run cabling through classrooms, install distribution switch and configure main router.', '2026-03-20', '08:17:00', '13:17:00', 300, 'assigned', 'normal', 25, '2026-03-20 05:29:20', '2026-03-20 05:29:20'),
(95, 'JOB-2026-0095', 'delivery', 'Eswatini Communications Commission', '792240169', 'Shop 2, Nhlangano Shopping Centre, Nhlangano', 'Deliver server rack components and structured cabling materials to government ICT department. Verify quantities on delivery note.', '2026-03-20', '13:11:00', '15:11:00', 120, 'assigned', 'urgent', 25, '2026-03-20 05:09:36', '2026-03-20 05:09:36'),
(96, 'JOB-2026-0096', 'miscellaneous', 'Nomvula Nkosi', '786173734', 'Plot 3, Mancishane Road, Manzini', 'Repair damaged patch panel port. Re-terminate cable, test continuity and confirm throughput restored.', '2026-03-20', '13:23:00', '14:23:00', 60, 'assigned', 'normal', 6, '2026-03-20 05:06:26', '2026-03-20 05:06:26'),
(97, 'JOB-2026-0097', 'miscellaneous', 'Zodwa Ngcamphalala', '791680832', 'Unit 3, Nhlangano Civic Centre, Nhlangano', 'Overhead drop cable sagging between poles causing signal loss. Re-tension, secure and test link stability.', '2026-03-20', '08:00:00', '10:00:00', 120, 'assigned', 'normal', 1, '2026-03-20 05:09:07', '2026-03-20 05:09:07'),
(98, 'JOB-2026-0098', 'miscellaneous', 'Eswatini Communications Commission', '785344625', 'Block C, Allister Miller Street, Mbabane', 'Overhead drop cable sagging between poles causing signal loss. Re-tension, secure and test link stability.', '2026-03-20', '10:18:00', '12:18:00', 120, 'assigned', 'urgent', 25, '2026-03-20 05:50:11', '2026-03-20 05:50:11'),
(99, 'JOB-2026-0099', 'installation', 'Lindiwe Gumede', '797618945', 'Unit 12, Sandlane Street, Manzini', 'Fibre to the business installation. Lay internal cabling, terminate patch panel and configure managed router.', '2026-03-23', '11:29:00', '15:29:00', 240, 'assigned', 'normal', 1, '2026-03-23 05:39:38', '2026-03-23 05:39:38'),
(100, 'JOB-2026-0100', 'miscellaneous', 'Nokukhanya Vilakati', '764344495', 'Unit 4, Ngwane Street, Manzini', 'Accompany sales representative to client site using company vehicle. Support product demonstration and collect signed quote.', '2026-03-23', '09:47:00', '11:47:00', 120, 'assigned', 'normal', 6, '2026-03-23 05:28:26', '2026-03-23 05:28:26'),
(101, 'JOB-2026-0101', 'miscellaneous', 'Phila Gamedze', '795609374', 'Shop 2, Nhlangano Shopping Centre, Nhlangano', 'Overhead drop cable sagging between poles causing signal loss. Re-tension, secure and test link stability.', '2026-03-23', '13:09:00', '15:09:00', 120, 'assigned', 'normal', 1, '2026-03-23 05:22:08', '2026-03-23 05:22:08'),
(102, 'JOB-2026-0102', 'delivery', 'Lungelo Mthembu', '768893544', 'Unit 15, Tex Ray Industrial Park, Matsapha', 'Deliver spare CPE units, cable reels and splicing materials to field technician team in Siteki.', '2026-03-23', '12:19:00', '13:49:00', 90, 'assigned', 'normal', 1, '2026-03-23 05:39:33', '2026-03-23 05:39:33'),
(103, 'JOB-2026-0103', 'miscellaneous', 'Thandeka Mnisi', '786802348', 'Plot 18, Louw Street, Manzini', 'Client unable to access internet after power outage. Reset router, verify ONT sync and reconfigure PPPoE settings.', '2026-03-23', '14:21:00', '15:21:00', 60, 'assigned', 'high', 25, '2026-03-23 05:56:49', '2026-03-23 05:56:49'),
(104, 'JOB-2026-0104', 'installation', 'Siyanda Motsa', '796808089', 'Plot 19, Lavumisa Road, Nhlangano', 'Install wireless internet equipment at business premises. Mount outdoor antenna on rooftop, configure CPE and test signal strength.', '2026-03-23', '08:05:00', '11:05:00', 180, 'assigned', 'normal', 25, '2026-03-23 05:46:09', '2026-03-23 05:46:09'),
(105, 'JOB-2026-0105', 'installation', 'Themba Dlamini', '778368902', 'Unit 5, Gilfillan Street, Mbabane', 'Set up new subscriber wireless connection. Install and aim outdoor unit, configure indoor router and run acceptance speed test.', '2026-03-23', '09:17:00', '11:47:00', 150, 'assigned', 'normal', 1, '2026-03-23 05:38:16', '2026-03-23 05:38:16'),
(106, 'JOB-2026-0106', 'miscellaneous', 'Ntombi Mngomezulu', '781645385', 'Plot 14, Mhlumeni Road, Siteki', 'Repair damaged patch panel port. Re-terminate cable, test continuity and confirm throughput restored.', '2026-03-23', '12:00:00', '13:00:00', 60, 'assigned', 'normal', 6, '2026-03-23 05:40:03', '2026-03-23 05:40:03'),
(107, 'JOB-2026-0107', 'delivery', 'RealNet Government Tender Office', '761663077', 'Plot 3, Mancishane Road, Manzini', 'Deliver fibre ONT units and router stock to corporate client warehouse in Matsapha. Collect signed GRN.', '2026-03-24', '11:17:00', '13:17:00', 120, 'assigned', 'high', 6, '2026-03-24 05:33:53', '2026-03-24 05:33:53'),
(108, 'JOB-2026-0108', 'miscellaneous', 'RealNet Government Tender Office', '783293731', 'Plot 11, King Sobhuza II Avenue, Nhlangano', 'Fibre cable cut reported near client premises. Locate break using OTDR, perform fusion splice and restore service.', '2026-03-24', '09:09:00', '12:09:00', 180, 'assigned', 'high', 1, '2026-03-24 05:56:32', '2026-03-24 05:56:32'),
(109, 'JOB-2026-0109', 'miscellaneous', 'Sifiso Hlophe', '799475008', 'Unit 9, Club Road, Mbabane', 'Survey school campus for network infrastructure upgrade. Document existing cabling, identify bottlenecks and propose improvements.', '2026-03-24', '09:06:00', '11:06:00', 120, 'assigned', 'normal', 1, '2026-03-24 05:07:12', '2026-03-24 05:07:12'),
(110, 'JOB-2026-0110', 'installation', 'Langelihle Fakudze', '785813288', 'Plot 6, MR11 Road, Nhlangano', 'Install network infrastructure for new apartment complex. Configure managed switches and deploy wireless access points per floor.', '2026-03-24', '11:27:00', '15:27:00', 240, 'assigned', 'normal', 25, '2026-03-24 05:25:16', '2026-03-24 05:25:16'),
(111, 'JOB-2026-0111', 'miscellaneous', 'Phila Gamedze', '777580314', 'Unit 3, Nhlangano Civic Centre, Nhlangano', 'Client unable to access internet after power outage. Reset router, verify ONT sync and reconfigure PPPoE settings.', '2026-03-24', '08:43:00', '09:43:00', 60, 'assigned', 'normal', 6, '2026-03-24 05:19:54', '2026-03-24 05:19:54'),
(112, 'JOB-2026-0112', 'miscellaneous', 'Sibonelo Msweli', '763854044', 'Unit 7, Industrial Road, Matsapha', 'Client reports intermittent connectivity. Inspect router configuration, check line quality and run speed diagnostics.', '2026-03-24', '12:55:00', '14:25:00', 90, 'assigned', 'urgent', 25, '2026-03-24 05:02:07', '2026-03-24 05:02:07'),
(113, 'JOB-2026-0113', 'miscellaneous', 'Sibonelo Msweli', '799788765', 'Unit 9, Club Road, Mbabane', 'Router rebooting randomly at business premises. Check firmware version, inspect power supply and update configuration.', '2026-03-24', '13:57:00', '15:27:00', 90, 'assigned', 'high', 1, '2026-03-24 05:56:01', '2026-03-24 05:56:01'),
(114, 'JOB-2026-0114', 'installation', 'Mpendulo Khumalo', '775968124', 'Unit 5, Gilfillan Street, Mbabane', 'Fibre to the business installation. Lay internal cabling, terminate patch panel and configure managed router.', '2026-03-25', '11:03:00', '15:03:00', 240, 'assigned', 'normal', 25, '2026-03-25 05:05:18', '2026-03-25 05:05:18'),
(115, 'JOB-2026-0115', 'miscellaneous', 'Phila Gamedze', '786229510', 'Shop 3, Swazi Plaza, Mbabane', 'Rodent damage to indoor patch cable reported. Replace chewed section, retest service and advise client on cable management.', '2026-03-25', '12:12:00', '13:12:00', 60, 'assigned', 'high', 25, '2026-03-25 05:23:15', '2026-03-25 05:23:15'),
(116, 'JOB-2026-0116', 'miscellaneous', 'Phiwayinkosi Mamba', '793480964', 'Unit 15, Tex Ray Industrial Park, Matsapha', 'Survey business premises for WiFi coverage assessment. Map signal dead zones and recommend access point placement.', '2026-03-25', '12:12:00', '13:42:00', 90, 'assigned', 'high', 6, '2026-03-25 05:55:51', '2026-03-25 05:55:51'),
(117, 'JOB-2026-0117', 'delivery', 'Phiwayinkosi Mamba', '772306713', 'Plot 55, Mhlakuvane Road, Manzini', 'Deliver sealed tender documents and technical proposal to Ministry of ICT offices as per submission deadline requirements.', '2026-03-25', '14:05:00', '15:35:00', 90, 'assigned', 'normal', 25, '2026-03-25 05:05:01', '2026-03-25 05:05:01'),
(118, 'JOB-2026-0118', 'miscellaneous', 'Mpendulo Khumalo', '779928231', 'Shop 2, Nhlangano Shopping Centre, Nhlangano', 'Repair damaged patch panel port. Re-terminate cable, test continuity and confirm throughput restored.', '2026-03-25', '14:45:00', '15:45:00', 60, 'assigned', 'urgent', 1, '2026-03-25 05:13:06', '2026-03-25 05:13:06'),
(119, 'JOB-2026-0119', 'delivery', 'Sibonelo Msweli', '792095256', 'Plot 11, King Sobhuza II Avenue, Nhlangano', 'Deliver spare CPE units, cable reels and splicing materials to field technician team in Siteki.', '2026-03-25', '08:51:00', '10:21:00', 90, 'assigned', 'urgent', 1, '2026-03-25 05:55:11', '2026-03-25 05:55:11'),
(120, 'JOB-2026-0120', 'miscellaneous', 'Zanele Mkhwanazi', '771918477', 'Plot 19, Lavumisa Road, Nhlangano', 'Client reports intermittent connectivity. Inspect router configuration, check line quality and run speed diagnostics.', '2026-03-26', '14:01:00', '15:31:00', 90, 'assigned', 'high', 6, '2026-03-26 05:36:16', '2026-03-26 05:36:16'),
(121, 'JOB-2026-0121', 'miscellaneous', 'Mandla Dube', '771039602', 'Plot 9, Ngwempisi Road, Matsapha', 'Survey business premises for WiFi coverage assessment. Map signal dead zones and recommend access point placement.', '2026-03-26', '13:32:00', '15:02:00', 90, 'assigned', 'urgent', 6, '2026-03-26 05:59:02', '2026-03-26 05:59:02'),
(122, 'JOB-2026-0122', 'miscellaneous', 'Ntombi Mngomezulu', '798969360', 'Shop 3, Swazi Plaza, Mbabane', 'Repair damaged patch panel port. Re-terminate cable, test continuity and confirm throughput restored.', '2026-03-26', '13:23:00', '14:23:00', 60, 'assigned', 'high', 25, '2026-03-26 05:27:40', '2026-03-26 05:27:40'),
(123, 'JOB-2026-0123', 'installation', 'Themba Dlamini', '796394227', 'Unit 4, Ngwane Street, Manzini', 'Fibre to the business installation. Lay internal cabling, terminate patch panel and configure managed router.', '2026-03-26', '09:26:00', '13:26:00', 240, 'assigned', 'high', 6, '2026-03-26 05:33:54', '2026-03-26 05:33:54'),
(124, 'JOB-2026-0124', 'installation', 'Lungisa Mavuso', '794706027', 'Plot 19, Lavumisa Road, Nhlangano', 'Fibre to the business installation. Lay internal cabling, terminate patch panel and configure managed router.', '2026-03-27', '12:55:00', '16:55:00', 240, 'assigned', 'urgent', 25, '2026-03-27 05:55:55', '2026-03-27 05:55:55'),
(125, 'JOB-2026-0125', 'miscellaneous', 'Lungisa Mavuso', '777062814', 'Block C, Allister Miller Street, Mbabane', 'Client unable to access internet after power outage. Reset router, verify ONT sync and reconfigure PPPoE settings.', '2026-03-27', '09:13:00', '10:13:00', 60, 'assigned', 'normal', 6, '2026-03-27 05:49:39', '2026-03-27 05:49:39'),
(126, 'JOB-2026-0126', 'miscellaneous', 'RealNet Government Tender Office', '763821228', 'Plot 8, Siteki Main Road, Siteki', 'Repair damaged patch panel port. Re-terminate cable, test continuity and confirm throughput restored.', '2026-03-27', '15:22:00', '16:22:00', 60, 'assigned', 'low', 25, '2026-03-27 05:36:26', '2026-03-27 05:36:26'),
(127, 'JOB-2026-0127', 'miscellaneous', 'Nomsa Ndzimandze', '792832321', 'Unit 4, Ngwane Street, Manzini', 'Conduct rooftop survey for planned wireless backhaul installation. Confirm line of sight to nearest tower and assess mounting options.', '2026-03-27', '13:13:00', '14:13:00', 60, 'assigned', 'urgent', 1, '2026-03-27 05:51:39', '2026-03-27 05:51:39'),
(128, 'JOB-2026-0128', 'miscellaneous', 'Siyanda Motsa', '799787094', 'Plot 33, Polinjane Road, Mbabane', 'Collect VIP client and transport to RealNet offices for account review meeting. Return client to premises after meeting.', '2026-03-27', '12:46:00', '14:16:00', 90, 'assigned', 'normal', 6, '2026-03-27 05:05:39', '2026-03-27 05:05:39'),
(129, 'JOB-2026-0129', 'miscellaneous', 'Sibusiso Nxumalo', '774706342', 'Shop 2, Nhlangano Shopping Centre, Nhlangano', 'Accompany sales representative to client site using company vehicle. Support product demonstration and collect signed quote.', '2026-03-27', '08:00:00', '10:00:00', 120, 'assigned', 'normal', 1, '2026-03-27 05:20:39', '2026-03-27 05:20:39'),
(130, 'JOB-2026-0130', 'installation', 'Lindiwe Gumede', '762195502', 'Plot 55, Mhlakuvane Road, Manzini', 'Install wireless internet equipment at business premises. Mount outdoor antenna on rooftop, configure CPE and test signal strength.', '2026-03-30', '09:06:00', '12:06:00', 180, 'pending', 'normal', 25, '2026-03-30 05:58:16', '2026-03-17 20:34:37'),
(131, 'JOB-2026-0131', 'installation', 'Mthokozisi Zwane', '788345041', 'Unit 3, Nhlangano Civic Centre, Nhlangano', 'Install new wireless point-to-point link between two office buildings. Align dishes and configure IP settings.', '2026-03-30', '10:38:00', '14:38:00', 240, 'assigned', 'low', 25, '2026-03-30 05:22:48', '2026-03-30 05:22:48'),
(132, 'JOB-2026-0132', 'miscellaneous', 'Lindiwe Gumede', '796194328', 'Unit 3, Nhlangano Civic Centre, Nhlangano', 'Client unable to access internet after power outage. Reset router, verify ONT sync and reconfigure PPPoE settings.', '2026-03-30', '10:36:00', '11:36:00', 60, 'assigned', 'normal', 25, '2026-03-30 05:11:07', '2026-03-30 05:11:07'),
(133, 'JOB-2026-0133', 'miscellaneous', 'Themba Dlamini', '793781635', 'Unit 15, Tex Ray Industrial Park, Matsapha', 'Overhead drop cable sagging between poles causing signal loss. Re-tension, secure and test link stability.', '2026-03-30', '13:26:00', '15:26:00', 120, 'pending', 'normal', 25, '2026-03-30 05:02:59', '2026-03-17 20:34:24'),
(134, 'JOB-2026-0134', 'miscellaneous', 'Mfanafuthi Masuku', '793579593', 'Plot 21, Matsapha Industrial Estate, Matsapha', 'Subscriber reporting speeds below subscribed plan. Check router QoS settings, run speed test and escalate if line fault found.', '2026-03-30', '13:10:00', '14:40:00', 90, 'assigned', 'normal', 6, '2026-03-30 05:30:59', '2026-03-30 05:30:59'),
(135, 'JOB-2026-0135', 'miscellaneous', 'Mandla Dube', '765745013', 'Plot 9, Ngwempisi Road, Matsapha', 'Client reports intermittent connectivity. Inspect router configuration, check line quality and run speed diagnostics.', '2026-03-30', '15:16:00', '16:46:00', 90, 'assigned', 'high', 25, '2026-03-30 05:18:55', '2026-03-30 05:18:55'),
(136, 'JOB-2026-0136', 'miscellaneous', 'Sifiso Hlophe', '763088529', 'Shop 2, Nhlangano Shopping Centre, Nhlangano', 'Client unable to access internet after power outage. Reset router, verify ONT sync and reconfigure PPPoE settings.', '2026-03-30', '08:04:00', '09:04:00', 60, 'assigned', 'urgent', 25, '2026-03-30 05:37:20', '2026-03-30 05:37:20'),
(137, 'JOB-2026-0137', 'delivery', 'Sithembile Bhembe', '787823814', 'Plot 11, King Sobhuza II Avenue, Nhlangano', 'Deliver ordered network hardware including switches, routers and patch panels to client site. Obtain signed delivery note.', '2026-03-30', '08:24:00', '10:24:00', 120, 'assigned', 'urgent', 25, '2026-03-30 05:03:42', '2026-03-30 05:03:42'),
(138, 'JOB-2026-0138', 'delivery', 'Sithembile Bhembe', '797274043', 'Shop 1, Siteki Plaza, Siteki', 'Deliver hardware accompanying tender bid to Eswatini Communications Commission offices. Confirm receipt with procurement officer.', '2026-03-30', '15:00:00', '16:30:00', 90, 'assigned', 'high', 25, '2026-03-30 05:41:05', '2026-03-30 05:41:05'),
(139, 'JOB-2026-0139', 'miscellaneous', 'Sipho Maseko', '776850794', 'Unit 4, Ngwane Street, Manzini', 'Overhead drop cable sagging between poles causing signal loss. Re-tension, secure and test link stability.', '2026-03-31', '14:51:00', '16:51:00', 120, 'assigned', 'low', 25, '2026-03-31 05:57:41', '2026-03-31 05:57:41'),
(140, 'JOB-2026-0140', 'installation', 'Mpendulo Khumalo', '798351515', 'Unit 7, Industrial Road, Matsapha', 'Install wireless internet equipment at business premises. Mount outdoor antenna on rooftop, configure CPE and test signal strength.', '2026-03-31', '10:43:00', '13:43:00', 180, 'assigned', 'low', 1, '2026-03-31 05:40:27', '2026-03-31 05:40:27'),
(141, 'JOB-2026-0141', 'installation', 'Sifiso Hlophe', '785678014', 'Shop 3, Swazi Plaza, Mbabane', 'New fibre line installation at residential property. Run drop cable from street pole, install ONT and configure router for new subscriber.', '2026-03-31', '10:12:00', '13:12:00', 180, 'assigned', 'low', 25, '2026-03-31 05:28:16', '2026-03-31 05:28:16'),
(142, 'JOB-2026-0142', 'installation', 'Phumzile Matsenjwa', '793559258', 'Plot 6, MR11 Road, Nhlangano', 'Install network infrastructure for new apartment complex. Configure managed switches and deploy wireless access points per floor.', '2026-03-31', '11:39:00', '15:39:00', 240, 'assigned', 'high', 25, '2026-03-31 05:29:43', '2026-03-31 05:29:43'),
(143, 'JOB-2026-0143', 'installation', 'Mandla Dube', '799839210', 'Shop 3, Swazi Plaza, Mbabane', 'Install wireless internet equipment at business premises. Mount outdoor antenna on rooftop, configure CPE and test signal strength.', '2026-03-31', '08:30:00', '11:30:00', 180, 'assigned', 'normal', 25, '2026-03-31 05:41:14', '2026-03-31 05:41:14'),
(144, 'JOB-2026-0144', 'miscellaneous', 'Sipho Maseko', '784564843', 'Plot 8, Siteki Main Road, Siteki', 'Drive sales team to corporate prospect presentation. Transport demonstration equipment and marketing materials.', '2026-03-31', '09:05:00', '10:35:00', 90, 'assigned', 'normal', 1, '2026-03-31 05:55:03', '2026-03-31 05:55:03');
INSERT INTO `jobs` (`id`, `job_number`, `job_type`, `customer_name`, `customer_phone`, `customer_address`, `description`, `scheduled_date`, `scheduled_time_start`, `scheduled_time_end`, `estimated_duration_minutes`, `current_status`, `priority`, `created_by`, `created_at`, `updated_at`) VALUES
(145, 'JOB-2026-0145', 'miscellaneous', 'Sibusiso Nxumalo', '775292467', 'Warehouse 3, Matsapha Airport Road, Matsapha', 'Conduct rooftop survey for planned wireless backhaul installation. Confirm line of sight to nearest tower and assess mounting options.', '2026-03-31', '14:09:00', '15:09:00', 60, 'assigned', 'normal', 6, '2026-03-31 05:26:36', '2026-03-31 05:26:36'),
(146, 'JOB-2026-0146', 'miscellaneous', 'Phiwayinkosi Mamba', '779151581', 'Shop 2, Nhlangano Shopping Centre, Nhlangano', 'Drive sales team to corporate prospect presentation. Transport demonstration equipment and marketing materials.', '2026-03-31', '15:12:00', '16:42:00', 90, 'assigned', 'normal', 25, '2026-03-31 05:17:47', '2026-03-31 05:17:47');

-- --------------------------------------------------------

--
-- Table structure for table `job_assignments`
--

CREATE TABLE `job_assignments` (
  `id` int(10) UNSIGNED NOT NULL,
  `job_id` int(10) UNSIGNED NOT NULL,
  `vehicle_id` int(10) UNSIGNED NOT NULL,
  `driver_id` int(10) UNSIGNED DEFAULT NULL,
  `assigned_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `assigned_by` int(10) UNSIGNED NOT NULL COMMENT 'User who made the assignment',
  `notes` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_assignments`
--

INSERT INTO `job_assignments` (`id`, `job_id`, `vehicle_id`, `driver_id`, `assigned_at`, `assigned_by`, `notes`) VALUES
(1, 1, 3, 8, '2026-03-03 05:34:30', 1, NULL),
(2, 2, 1, 12, '2026-03-03 05:03:53', 6, NULL),
(3, 3, 3, 19, '2026-03-03 05:05:01', 6, NULL),
(4, 4, 2, 21, '2026-03-03 05:01:03', 1, NULL),
(5, 5, 1, 7, '2026-03-03 05:05:42', 1, NULL),
(6, 6, 2, 20, '2026-03-03 05:12:56', 25, NULL),
(7, 7, 2, 9, '2026-03-03 05:03:13', 25, NULL),
(8, 8, 2, 20, '2026-03-04 05:39:37', 6, NULL),
(9, 9, 2, 15, '2026-03-04 05:40:58', 1, NULL),
(10, 10, 1, 7, '2026-03-04 05:41:19', 25, NULL),
(11, 11, 1, 7, '2026-03-04 05:00:58', 6, NULL),
(12, 12, 3, 10, '2026-03-04 05:32:55', 6, NULL),
(13, 13, 3, 21, '2026-03-04 05:37:06', 25, NULL),
(14, 14, 3, 20, '2026-03-04 05:31:14', 6, NULL),
(15, 15, 2, 12, '2026-03-04 05:28:14', 6, NULL),
(16, 16, 3, 10, '2026-03-05 05:25:06', 1, NULL),
(17, 17, 3, 17, '2026-03-05 05:12:13', 1, NULL),
(18, 18, 1, 23, '2026-03-05 05:47:57', 6, NULL),
(19, 19, 1, 16, '2026-03-05 05:27:20', 25, NULL),
(20, 20, 2, 24, '2026-03-05 05:02:27', 25, NULL),
(21, 21, 1, 16, '2026-03-05 05:55:36', 6, NULL),
(22, 22, 2, 15, '2026-03-06 05:11:02', 25, NULL),
(23, 23, 2, 24, '2026-03-06 05:58:31', 6, NULL),
(24, 24, 3, 11, '2026-03-06 05:16:16', 6, NULL),
(25, 25, 1, 17, '2026-03-06 05:19:43', 6, NULL),
(26, 26, 1, 20, '2026-03-06 05:43:13', 25, NULL),
(27, 27, 3, 21, '2026-03-06 05:04:58', 6, NULL),
(28, 28, 2, 14, '2026-03-06 05:27:24', 25, NULL),
(29, 29, 2, 8, '2026-03-09 05:45:54', 1, NULL),
(30, 30, 1, 17, '2026-03-09 05:22:15', 6, NULL),
(31, 31, 3, 21, '2026-03-09 05:46:22', 1, NULL),
(32, 32, 2, 23, '2026-03-09 05:03:59', 25, NULL),
(33, 33, 2, 14, '2026-03-09 05:43:31', 1, NULL),
(34, 34, 3, 20, '2026-03-09 05:42:19', 1, NULL),
(35, 35, 1, 10, '2026-03-09 05:03:16', 1, NULL),
(36, 36, 3, 15, '2026-03-09 05:29:48', 1, NULL),
(37, 37, 1, 13, '2026-03-09 05:39:08', 25, NULL),
(38, 38, 2, 8, '2026-03-10 05:29:26', 6, NULL),
(39, 39, 1, 17, '2026-03-10 05:39:08', 6, NULL),
(40, 40, 3, 10, '2026-03-10 05:07:07', 25, NULL),
(41, 41, 3, 7, '2026-03-10 05:44:58', 6, NULL),
(42, 42, 2, 12, '2026-03-10 05:30:26', 1, NULL),
(43, 43, 1, 8, '2026-03-10 05:20:31', 6, NULL),
(44, 44, 3, 20, '2026-03-10 05:43:43', 6, NULL),
(45, 45, 3, 22, '2026-03-10 05:20:00', 25, NULL),
(46, 46, 2, 15, '2026-03-11 05:52:48', 6, NULL),
(47, 47, 3, 10, '2026-03-11 05:03:26', 1, NULL),
(48, 48, 2, 7, '2026-03-11 05:24:07', 6, NULL),
(49, 49, 1, 22, '2026-03-11 05:28:38', 1, NULL),
(50, 50, 2, 18, '2026-03-11 05:54:51', 25, NULL),
(51, 51, 2, 17, '2026-03-11 05:37:32', 25, NULL),
(52, 52, 1, 15, '2026-03-12 05:17:38', 1, NULL),
(53, 53, 1, 12, '2026-03-12 05:03:10', 6, NULL),
(54, 54, 1, 17, '2026-03-12 05:31:38', 6, NULL),
(55, 55, 3, 21, '2026-03-12 05:47:33', 6, NULL),
(56, 56, 2, 7, '2026-03-13 05:41:31', 6, NULL),
(57, 57, 2, 7, '2026-03-13 05:20:33', 6, NULL),
(58, 58, 1, 21, '2026-03-13 05:23:03', 1, NULL),
(59, 59, 1, 20, '2026-03-13 05:00:55', 6, NULL),
(60, 60, 3, 13, '2026-03-13 05:35:31', 1, NULL),
(61, 61, 3, 22, '2026-03-13 05:47:06', 6, NULL),
(62, 62, 1, 14, '2026-03-13 05:52:41', 25, NULL),
(63, 63, 1, 12, '2026-03-16 05:37:18', 6, NULL),
(64, 64, 1, 13, '2026-03-16 05:35:50', 6, NULL),
(65, 65, 3, 17, '2026-03-16 05:59:00', 25, NULL),
(66, 66, 2, 21, '2026-03-16 05:46:02', 1, NULL),
(67, 67, 2, 8, '2026-03-16 05:46:59', 1, NULL),
(68, 68, 3, 15, '2026-03-16 05:35:46', 6, NULL),
(69, 69, 2, 16, '2026-03-16 05:38:40', 25, NULL),
(70, 70, 3, 17, '2026-03-16 05:44:46', 6, NULL),
(71, 71, 3, 15, '2026-03-17 05:37:37', 6, NULL),
(72, 72, 2, 7, '2026-03-17 05:14:04', 1, NULL),
(73, 73, 2, 13, '2026-03-17 05:14:06', 1, NULL),
(74, 74, 1, 18, '2026-03-17 05:52:54', 25, NULL),
(75, 75, 1, 24, '2026-03-17 05:54:00', 25, NULL),
(76, 76, 3, 24, '2026-03-17 05:39:02', 6, NULL),
(77, 77, 2, 22, '2026-03-17 05:46:56', 6, NULL),
(78, 78, 1, 16, '2026-03-17 05:24:57', 1, NULL),
(79, 79, 3, 14, '2026-03-18 05:22:08', 25, NULL),
(80, 80, 1, 7, '2026-03-18 05:04:30', 1, NULL),
(81, 81, 2, 23, '2026-03-18 05:59:20', 1, NULL),
(82, 82, 3, 15, '2026-03-18 05:25:42', 25, NULL),
(83, 83, 3, 15, '2026-03-18 05:27:43', 25, NULL),
(84, 84, 2, 24, '2026-03-18 05:22:14', 25, NULL),
(85, 85, 1, 11, '2026-03-18 05:06:26', 6, NULL),
(86, 86, 3, 22, '2026-03-18 05:49:07', 1, NULL),
(87, 87, 3, 17, '2026-03-19 05:31:44', 25, NULL),
(88, 88, 2, 8, '2026-03-19 05:23:34', 1, NULL),
(89, 89, 1, 24, '2026-03-19 05:50:55', 25, NULL),
(90, 90, 3, 19, '2026-03-19 05:05:03', 1, NULL),
(91, 91, 2, 12, '2026-03-19 05:47:16', 6, NULL),
(92, 92, 3, 23, '2026-03-19 05:27:14', 1, NULL),
(93, 93, 3, 10, '2026-03-20 05:03:53', 6, NULL),
(94, 94, 1, 23, '2026-03-20 05:29:20', 1, NULL),
(95, 95, 2, 9, '2026-03-20 05:09:36', 1, NULL),
(96, 96, 1, 23, '2026-03-20 05:06:26', 25, NULL),
(97, 97, 3, 7, '2026-03-20 05:09:07', 25, NULL),
(98, 98, 2, 11, '2026-03-20 05:50:11', 25, NULL),
(99, 99, 3, 21, '2026-03-23 05:39:38', 1, NULL),
(100, 100, 1, 20, '2026-03-23 05:28:26', 1, NULL),
(101, 101, 1, 22, '2026-03-23 05:22:08', 1, NULL),
(102, 102, 2, 15, '2026-03-23 05:39:33', 1, NULL),
(103, 103, 2, 11, '2026-03-23 05:56:49', 6, NULL),
(104, 104, 3, 24, '2026-03-23 05:46:09', 6, NULL),
(105, 105, 2, 18, '2026-03-23 05:38:16', 6, NULL),
(106, 106, 1, 17, '2026-03-23 05:40:03', 25, NULL),
(107, 107, 3, 16, '2026-03-24 05:33:53', 1, NULL),
(108, 108, 1, 21, '2026-03-24 05:56:32', 1, NULL),
(109, 109, 3, 24, '2026-03-24 05:07:12', 1, NULL),
(110, 110, 2, 22, '2026-03-24 05:25:16', 1, NULL),
(111, 111, 2, 19, '2026-03-24 05:19:54', 25, NULL),
(112, 112, 1, 18, '2026-03-24 05:02:07', 1, NULL),
(113, 113, 3, 19, '2026-03-24 05:56:01', 6, NULL),
(114, 114, 1, 10, '2026-03-25 05:05:18', 6, NULL),
(115, 115, 2, 22, '2026-03-25 05:23:15', 25, NULL),
(116, 116, 3, 11, '2026-03-25 05:55:51', 1, NULL),
(117, 117, 2, 22, '2026-03-25 05:05:01', 1, NULL),
(118, 118, 3, 18, '2026-03-25 05:13:06', 25, NULL),
(119, 119, 1, 19, '2026-03-25 05:55:11', 6, NULL),
(120, 120, 3, 22, '2026-03-26 05:36:16', 6, NULL),
(121, 121, 2, 15, '2026-03-26 05:59:02', 25, NULL),
(122, 122, 1, 8, '2026-03-26 05:27:40', 1, NULL),
(123, 123, 3, 14, '2026-03-26 05:33:54', 6, NULL),
(124, 124, 1, 12, '2026-03-27 05:55:55', 25, NULL),
(125, 125, 1, 21, '2026-03-27 05:49:39', 6, NULL),
(126, 126, 2, 24, '2026-03-27 05:36:26', 1, NULL),
(127, 127, 2, 19, '2026-03-27 05:51:39', 25, NULL),
(128, 128, 3, 20, '2026-03-27 05:05:39', 1, NULL),
(129, 129, 2, 20, '2026-03-27 05:20:39', 25, NULL),
(131, 131, 3, 11, '2026-03-30 05:22:48', 1, NULL),
(132, 132, 2, 16, '2026-03-30 05:11:07', 6, NULL),
(134, 134, 2, 23, '2026-03-30 05:30:59', 25, NULL),
(135, 135, 3, 24, '2026-03-30 05:18:55', 6, NULL),
(136, 136, 1, 22, '2026-03-30 05:37:20', 6, NULL),
(137, 137, 3, 24, '2026-03-30 05:03:42', 6, NULL),
(138, 138, 2, 18, '2026-03-30 05:41:05', 6, NULL),
(139, 139, 2, 11, '2026-03-31 05:57:41', 1, NULL),
(140, 140, 2, 15, '2026-03-31 05:40:27', 1, NULL),
(141, 141, 1, 17, '2026-03-31 05:28:16', 1, NULL),
(142, 142, 3, 21, '2026-03-31 05:29:43', 1, NULL),
(143, 143, 3, 11, '2026-03-31 05:41:14', 6, NULL),
(144, 144, 2, 20, '2026-03-31 05:55:03', 1, NULL),
(145, 145, 1, 23, '2026-03-31 05:26:36', 25, NULL),
(146, 146, 1, 20, '2026-03-31 05:17:47', 25, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `job_status_changes`
--

CREATE TABLE `job_status_changes` (
  `id` int(10) UNSIGNED NOT NULL,
  `job_id` int(10) UNSIGNED NOT NULL,
  `old_status` enum('pending','assigned','in_progress','completed','cancelled') DEFAULT NULL,
  `new_status` enum('pending','assigned','in_progress','completed','cancelled') NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `changed_by` int(10) UNSIGNED NOT NULL,
  `changed_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `notes` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_status_changes`
--

INSERT INTO `job_status_changes` (`id`, `job_id`, `old_status`, `new_status`, `reason`, `changed_by`, `changed_at`, `notes`) VALUES
(1, 1, 'pending', 'assigned', NULL, 6, '2026-03-03 05:34:30', NULL),
(2, 1, 'assigned', 'in_progress', NULL, 8, '2026-03-03 06:58:00', NULL),
(3, 1, 'in_progress', 'completed', NULL, 8, '2026-03-03 09:28:00', NULL),
(4, 2, 'pending', 'assigned', NULL, 25, '2026-03-03 05:03:53', NULL),
(5, 2, 'assigned', 'in_progress', NULL, 12, '2026-03-03 06:41:00', NULL),
(6, 2, 'in_progress', 'completed', NULL, 12, '2026-03-03 09:41:00', NULL),
(7, 3, 'pending', 'assigned', NULL, 25, '2026-03-03 05:05:01', NULL),
(8, 4, 'pending', 'assigned', NULL, 1, '2026-03-03 05:01:03', NULL),
(9, 4, 'assigned', 'in_progress', NULL, 21, '2026-03-03 06:00:00', NULL),
(10, 5, 'pending', 'assigned', NULL, 1, '2026-03-03 05:05:42', NULL),
(11, 5, 'assigned', 'in_progress', NULL, 7, '2026-03-03 12:04:00', NULL),
(12, 6, 'pending', 'assigned', NULL, 6, '2026-03-03 05:12:56', NULL),
(13, 6, 'assigned', 'in_progress', NULL, 20, '2026-03-03 12:38:00', NULL),
(14, 6, 'in_progress', 'completed', NULL, 20, '2026-03-03 14:08:00', NULL),
(15, 7, 'pending', 'assigned', NULL, 25, '2026-03-03 05:03:13', NULL),
(16, 7, 'assigned', 'in_progress', NULL, 9, '2026-03-03 08:25:00', NULL),
(17, 8, 'pending', 'assigned', NULL, 25, '2026-03-04 05:39:37', NULL),
(18, 8, 'assigned', 'in_progress', NULL, 20, '2026-03-04 07:01:00', NULL),
(19, 8, 'in_progress', 'completed', NULL, 20, '2026-03-04 08:31:00', NULL),
(20, 9, 'pending', 'assigned', NULL, 6, '2026-03-04 05:40:58', NULL),
(21, 9, 'assigned', 'in_progress', NULL, 15, '2026-03-04 08:33:00', NULL),
(22, 9, 'in_progress', 'completed', NULL, 15, '2026-03-04 12:33:00', NULL),
(23, 10, 'pending', 'assigned', NULL, 25, '2026-03-04 05:41:19', NULL),
(24, 10, 'assigned', 'in_progress', NULL, 7, '2026-03-04 09:18:00', NULL),
(25, 10, 'in_progress', 'completed', NULL, 7, '2026-03-04 13:18:00', NULL),
(26, 11, 'pending', 'assigned', NULL, 1, '2026-03-04 05:00:58', NULL),
(27, 11, 'assigned', 'in_progress', NULL, 7, '2026-03-04 07:37:00', NULL),
(28, 11, 'in_progress', 'completed', NULL, 7, '2026-03-04 08:37:00', NULL),
(29, 12, 'pending', 'assigned', NULL, 6, '2026-03-04 05:32:55', NULL),
(30, 12, 'assigned', 'in_progress', NULL, 10, '2026-03-04 10:28:00', NULL),
(31, 13, 'pending', 'assigned', NULL, 6, '2026-03-04 05:37:06', NULL),
(32, 13, 'assigned', 'in_progress', NULL, 21, '2026-03-04 06:56:00', NULL),
(33, 14, 'pending', 'assigned', NULL, 25, '2026-03-04 05:31:14', NULL),
(34, 14, 'assigned', 'in_progress', NULL, 20, '2026-03-04 12:14:00', NULL),
(35, 14, 'in_progress', 'completed', NULL, 20, '2026-03-04 13:44:00', NULL),
(36, 15, 'pending', 'assigned', NULL, 6, '2026-03-04 05:28:14', NULL),
(37, 15, 'assigned', 'cancelled', 'Vehicle breakdown en route', 12, '2026-03-04 13:04:00', NULL),
(38, 16, 'pending', 'assigned', NULL, 25, '2026-03-05 05:25:06', NULL),
(39, 16, 'assigned', 'cancelled', 'Customer not available at premises', 10, '2026-03-05 12:03:00', NULL),
(40, 17, 'pending', 'assigned', NULL, 1, '2026-03-05 05:12:13', NULL),
(41, 17, 'assigned', 'cancelled', 'Customer requested reschedule', 17, '2026-03-05 06:07:00', NULL),
(42, 18, 'pending', 'assigned', NULL, 1, '2026-03-05 05:47:57', NULL),
(43, 18, 'assigned', 'in_progress', NULL, 23, '2026-03-05 06:56:00', NULL),
(44, 18, 'in_progress', 'completed', NULL, 23, '2026-03-05 08:56:00', NULL),
(45, 19, 'pending', 'assigned', NULL, 6, '2026-03-05 05:27:20', NULL),
(46, 19, 'assigned', 'in_progress', NULL, 16, '2026-03-05 09:28:00', NULL),
(47, 19, 'in_progress', 'completed', NULL, 16, '2026-03-05 10:28:00', NULL),
(48, 20, 'pending', 'assigned', NULL, 6, '2026-03-05 05:02:27', NULL),
(49, 20, 'assigned', 'in_progress', NULL, 24, '2026-03-05 08:36:00', NULL),
(50, 20, 'in_progress', 'completed', NULL, 24, '2026-03-05 11:36:00', NULL),
(51, 21, 'pending', 'assigned', NULL, 25, '2026-03-05 05:55:36', NULL),
(52, 21, 'assigned', 'in_progress', NULL, 16, '2026-03-05 11:19:00', NULL),
(53, 21, 'in_progress', 'completed', NULL, 16, '2026-03-05 13:19:00', NULL),
(54, 22, 'pending', 'assigned', NULL, 6, '2026-03-06 05:11:02', NULL),
(55, 22, 'assigned', 'in_progress', NULL, 15, '2026-03-06 06:47:00', NULL),
(56, 22, 'in_progress', 'completed', NULL, 15, '2026-03-06 08:17:00', NULL),
(57, 23, 'pending', 'assigned', NULL, 25, '2026-03-06 05:58:31', NULL),
(58, 23, 'assigned', 'in_progress', NULL, 24, '2026-03-06 12:43:00', NULL),
(59, 23, 'in_progress', 'completed', NULL, 24, '2026-03-06 14:13:00', NULL),
(60, 24, 'pending', 'assigned', NULL, 1, '2026-03-06 05:16:16', NULL),
(61, 24, 'assigned', 'in_progress', NULL, 11, '2026-03-06 07:19:00', NULL),
(62, 24, 'in_progress', 'completed', NULL, 11, '2026-03-06 12:19:00', NULL),
(63, 25, 'pending', 'assigned', NULL, 1, '2026-03-06 05:19:43', NULL),
(64, 25, 'assigned', 'in_progress', NULL, 17, '2026-03-06 11:58:00', NULL),
(65, 25, 'in_progress', 'completed', NULL, 17, '2026-03-06 13:28:00', NULL),
(66, 26, 'pending', 'assigned', NULL, 25, '2026-03-06 05:43:13', NULL),
(67, 26, 'assigned', 'in_progress', NULL, 20, '2026-03-06 06:55:00', NULL),
(68, 26, 'in_progress', 'completed', NULL, 20, '2026-03-06 08:55:00', NULL),
(69, 27, 'pending', 'assigned', NULL, 6, '2026-03-06 05:04:58', NULL),
(70, 27, 'assigned', 'in_progress', NULL, 21, '2026-03-06 12:55:00', NULL),
(71, 27, 'in_progress', 'completed', NULL, 21, '2026-03-06 14:55:00', NULL),
(72, 28, 'pending', 'assigned', NULL, 1, '2026-03-06 05:27:24', NULL),
(73, 28, 'assigned', 'in_progress', NULL, 14, '2026-03-06 09:14:00', NULL),
(74, 28, 'in_progress', 'completed', NULL, 14, '2026-03-06 10:44:00', NULL),
(75, 29, 'pending', 'assigned', NULL, 1, '2026-03-09 05:45:54', NULL),
(76, 29, 'assigned', 'in_progress', NULL, 8, '2026-03-09 08:22:00', NULL),
(77, 30, 'pending', 'assigned', NULL, 25, '2026-03-09 05:22:15', NULL),
(78, 30, 'assigned', 'in_progress', NULL, 17, '2026-03-09 08:50:00', NULL),
(79, 30, 'in_progress', 'completed', NULL, 17, '2026-03-09 11:20:00', NULL),
(80, 31, 'pending', 'assigned', NULL, 6, '2026-03-09 05:46:22', NULL),
(81, 31, 'assigned', 'in_progress', NULL, 21, '2026-03-09 07:42:00', NULL),
(82, 31, 'in_progress', 'completed', NULL, 21, '2026-03-09 09:12:00', NULL),
(83, 32, 'pending', 'assigned', NULL, 1, '2026-03-09 05:03:59', NULL),
(84, 32, 'assigned', 'in_progress', NULL, 23, '2026-03-09 13:08:00', NULL),
(85, 32, 'in_progress', 'completed', NULL, 23, '2026-03-09 14:38:00', NULL),
(86, 33, 'pending', 'assigned', NULL, 6, '2026-03-09 05:43:31', NULL),
(87, 33, 'assigned', 'in_progress', NULL, 14, '2026-03-09 10:41:00', NULL),
(88, 33, 'in_progress', 'completed', NULL, 14, '2026-03-09 11:41:00', NULL),
(89, 34, 'pending', 'assigned', NULL, 1, '2026-03-09 05:42:19', NULL),
(90, 34, 'assigned', 'cancelled', 'Customer not available at premises', 20, '2026-03-09 10:34:00', NULL),
(91, 35, 'pending', 'assigned', NULL, 25, '2026-03-09 05:03:16', NULL),
(92, 35, 'assigned', 'in_progress', NULL, 10, '2026-03-09 12:04:00', NULL),
(93, 35, 'in_progress', 'completed', NULL, 10, '2026-03-09 13:34:00', NULL),
(94, 36, 'pending', 'assigned', NULL, 1, '2026-03-09 05:29:48', NULL),
(95, 36, 'assigned', 'in_progress', NULL, 15, '2026-03-09 12:44:00', NULL),
(96, 36, 'in_progress', 'completed', NULL, 15, '2026-03-09 14:14:00', NULL),
(97, 37, 'pending', 'assigned', NULL, 25, '2026-03-09 05:39:08', NULL),
(98, 37, 'assigned', 'in_progress', NULL, 13, '2026-03-09 06:23:00', NULL),
(99, 38, 'pending', 'assigned', NULL, 25, '2026-03-10 05:29:26', NULL),
(100, 38, 'assigned', 'in_progress', NULL, 8, '2026-03-10 06:12:00', NULL),
(101, 38, 'in_progress', 'completed', NULL, 8, '2026-03-10 10:12:00', NULL),
(102, 39, 'pending', 'assigned', NULL, 6, '2026-03-10 05:39:08', NULL),
(103, 39, 'assigned', 'cancelled', 'Power outage at site prevented work', 17, '2026-03-10 06:04:00', NULL),
(104, 40, 'pending', 'assigned', NULL, 25, '2026-03-10 05:07:07', NULL),
(105, 40, 'assigned', 'cancelled', 'Road closure due to flooding', 10, '2026-03-10 06:01:00', NULL),
(106, 41, 'pending', 'assigned', NULL, 6, '2026-03-10 05:44:58', NULL),
(107, 41, 'assigned', 'cancelled', 'Customer not available at premises', 7, '2026-03-10 09:09:00', NULL),
(108, 42, 'pending', 'assigned', NULL, 6, '2026-03-10 05:30:26', NULL),
(109, 42, 'assigned', 'in_progress', NULL, 12, '2026-03-10 12:42:00', NULL),
(110, 42, 'in_progress', 'completed', NULL, 12, '2026-03-10 14:42:00', NULL),
(111, 43, 'pending', 'assigned', NULL, 1, '2026-03-10 05:20:31', NULL),
(112, 43, 'assigned', 'in_progress', NULL, 8, '2026-03-10 12:00:00', NULL),
(113, 44, 'pending', 'assigned', NULL, 6, '2026-03-10 05:43:43', NULL),
(114, 44, 'assigned', 'in_progress', NULL, 20, '2026-03-10 13:00:00', NULL),
(115, 45, 'pending', 'assigned', NULL, 1, '2026-03-10 05:20:00', NULL),
(116, 46, 'pending', 'assigned', NULL, 25, '2026-03-11 05:52:48', NULL),
(117, 46, 'assigned', 'in_progress', NULL, 15, '2026-03-11 08:51:00', NULL),
(118, 46, 'in_progress', 'completed', NULL, 15, '2026-03-11 09:51:00', NULL),
(119, 47, 'pending', 'assigned', NULL, 1, '2026-03-11 05:03:26', NULL),
(120, 47, 'assigned', 'in_progress', NULL, 10, '2026-03-11 07:24:00', NULL),
(121, 47, 'in_progress', 'completed', NULL, 10, '2026-03-11 09:24:00', NULL),
(122, 48, 'pending', 'assigned', NULL, 25, '2026-03-11 05:24:07', NULL),
(123, 48, 'assigned', 'in_progress', NULL, 7, '2026-03-11 11:44:00', NULL),
(124, 48, 'in_progress', 'completed', NULL, 7, '2026-03-11 13:14:00', NULL),
(125, 49, 'pending', 'assigned', NULL, 25, '2026-03-11 05:28:38', NULL),
(126, 49, 'assigned', 'cancelled', 'Technician fell ill', 22, '2026-03-11 08:48:00', NULL),
(127, 50, 'pending', 'assigned', NULL, 25, '2026-03-11 05:54:51', NULL),
(128, 50, 'assigned', 'in_progress', NULL, 18, '2026-03-11 13:16:00', NULL),
(129, 50, 'in_progress', 'completed', NULL, 18, '2026-03-11 14:46:00', NULL),
(130, 51, 'pending', 'assigned', NULL, 25, '2026-03-11 05:37:32', NULL),
(131, 51, 'assigned', 'in_progress', NULL, 17, '2026-03-11 07:14:00', NULL),
(132, 52, 'pending', 'assigned', NULL, 1, '2026-03-12 05:17:38', NULL),
(133, 52, 'assigned', 'in_progress', NULL, 15, '2026-03-12 09:26:00', NULL),
(134, 52, 'in_progress', 'completed', NULL, 15, '2026-03-12 10:26:00', NULL),
(135, 53, 'pending', 'assigned', NULL, 1, '2026-03-12 05:03:10', NULL),
(136, 53, 'assigned', 'cancelled', 'Customer requested reschedule', 12, '2026-03-12 11:44:00', NULL),
(137, 54, 'pending', 'assigned', NULL, 1, '2026-03-12 05:31:38', NULL),
(138, 54, 'assigned', 'in_progress', NULL, 17, '2026-03-12 07:12:00', NULL),
(139, 54, 'in_progress', 'completed', NULL, 17, '2026-03-12 09:12:00', NULL),
(140, 55, 'pending', 'assigned', NULL, 25, '2026-03-12 05:47:33', NULL),
(141, 55, 'assigned', 'in_progress', NULL, 21, '2026-03-12 06:29:00', NULL),
(142, 55, 'in_progress', 'completed', NULL, 21, '2026-03-12 08:29:00', NULL),
(143, 56, 'pending', 'assigned', NULL, 25, '2026-03-13 05:41:31', NULL),
(144, 56, 'assigned', 'cancelled', 'Power outage at site prevented work', 7, '2026-03-13 07:06:00', NULL),
(145, 57, 'pending', 'assigned', NULL, 1, '2026-03-13 05:20:33', NULL),
(146, 57, 'assigned', 'in_progress', NULL, 7, '2026-03-13 12:51:00', NULL),
(147, 57, 'in_progress', 'completed', NULL, 7, '2026-03-13 14:21:00', NULL),
(148, 58, 'pending', 'assigned', NULL, 1, '2026-03-13 05:23:03', NULL),
(149, 58, 'assigned', 'in_progress', NULL, 21, '2026-03-13 11:56:00', NULL),
(150, 58, 'in_progress', 'completed', NULL, 21, '2026-03-13 14:56:00', NULL),
(151, 59, 'pending', 'assigned', NULL, 25, '2026-03-13 05:00:55', NULL),
(152, 59, 'assigned', 'in_progress', NULL, 20, '2026-03-13 06:55:00', NULL),
(153, 59, 'in_progress', 'completed', NULL, 20, '2026-03-13 08:25:00', NULL),
(154, 60, 'pending', 'assigned', NULL, 25, '2026-03-13 05:35:31', NULL),
(155, 61, 'pending', 'assigned', NULL, 6, '2026-03-13 05:47:06', NULL),
(156, 61, 'assigned', 'in_progress', NULL, 22, '2026-03-13 07:23:00', NULL),
(157, 61, 'in_progress', 'completed', NULL, 22, '2026-03-13 11:23:00', NULL),
(158, 62, 'pending', 'assigned', NULL, 1, '2026-03-13 05:52:41', NULL),
(159, 62, 'assigned', 'in_progress', NULL, 14, '2026-03-13 08:45:00', NULL),
(160, 62, 'in_progress', 'completed', NULL, 14, '2026-03-13 11:45:00', NULL),
(161, 63, 'pending', 'assigned', NULL, 6, '2026-03-16 05:37:18', NULL),
(162, 63, 'assigned', 'in_progress', NULL, 12, '2026-03-16 06:35:00', NULL),
(163, 64, 'pending', 'assigned', NULL, 1, '2026-03-16 05:35:50', NULL),
(164, 64, 'assigned', 'in_progress', NULL, 13, '2026-03-16 12:49:00', NULL),
(165, 64, 'in_progress', 'completed', NULL, 13, '2026-03-16 14:49:00', NULL),
(166, 65, 'pending', 'assigned', NULL, 1, '2026-03-16 05:59:00', NULL),
(167, 65, 'assigned', 'in_progress', NULL, 17, '2026-03-16 06:13:00', NULL),
(168, 66, 'pending', 'assigned', NULL, 6, '2026-03-16 05:46:02', NULL),
(169, 66, 'assigned', 'cancelled', 'No line of sight confirmed on arrival', 21, '2026-03-16 07:20:00', NULL),
(170, 67, 'pending', 'assigned', NULL, 6, '2026-03-16 05:46:59', NULL),
(171, 67, 'assigned', 'in_progress', NULL, 8, '2026-03-16 09:23:00', NULL),
(172, 67, 'in_progress', 'completed', NULL, 8, '2026-03-16 13:23:00', NULL),
(173, 68, 'pending', 'assigned', NULL, 6, '2026-03-16 05:35:46', NULL),
(174, 68, 'assigned', 'in_progress', NULL, 15, '2026-03-16 11:31:00', NULL),
(175, 68, 'in_progress', 'completed', NULL, 15, '2026-03-16 14:01:00', NULL),
(176, 69, 'pending', 'assigned', NULL, 6, '2026-03-16 05:38:40', NULL),
(177, 69, 'assigned', 'in_progress', NULL, 16, '2026-03-16 13:24:00', NULL),
(178, 69, 'in_progress', 'completed', NULL, 16, '2026-03-16 14:54:00', NULL),
(179, 70, 'pending', 'assigned', NULL, 25, '2026-03-16 05:44:46', NULL),
(180, 70, 'assigned', 'in_progress', NULL, 17, '2026-03-16 10:15:00', NULL),
(181, 70, 'in_progress', 'completed', NULL, 17, '2026-03-16 11:15:00', NULL),
(182, 71, 'pending', 'assigned', NULL, 1, '2026-03-17 05:37:37', NULL),
(183, 71, 'assigned', 'in_progress', NULL, 15, '2026-03-17 09:38:00', NULL),
(184, 71, 'in_progress', 'completed', NULL, 15, '2026-03-17 13:38:00', NULL),
(185, 72, 'pending', 'assigned', NULL, 1, '2026-03-17 05:14:04', NULL),
(186, 72, 'assigned', 'in_progress', NULL, 7, '2026-03-17 11:52:00', NULL),
(187, 73, 'pending', 'assigned', NULL, 25, '2026-03-17 05:14:06', NULL),
(188, 73, 'assigned', 'in_progress', NULL, 13, '2026-03-17 08:25:00', NULL),
(189, 73, 'in_progress', 'completed', NULL, 13, '2026-03-17 10:25:00', NULL),
(190, 74, 'pending', 'assigned', NULL, 6, '2026-03-17 05:52:54', NULL),
(191, 74, 'assigned', 'in_progress', NULL, 18, '2026-03-17 13:09:00', NULL),
(192, 74, 'in_progress', 'completed', NULL, 18, '2026-03-17 14:39:00', NULL),
(193, 75, 'pending', 'assigned', NULL, 25, '2026-03-17 05:54:00', NULL),
(194, 75, 'assigned', 'in_progress', NULL, 24, '2026-03-17 10:13:00', NULL),
(195, 75, 'in_progress', 'completed', NULL, 24, '2026-03-17 12:13:00', NULL),
(196, 76, 'pending', 'assigned', NULL, 1, '2026-03-17 05:39:02', NULL),
(197, 76, 'assigned', 'in_progress', NULL, 24, '2026-03-17 06:11:00', NULL),
(198, 76, 'in_progress', 'completed', NULL, 24, '2026-03-17 09:11:00', NULL),
(199, 77, 'pending', 'assigned', NULL, 1, '2026-03-17 05:46:56', NULL),
(200, 77, 'assigned', 'cancelled', 'Road closure due to flooding', 22, '2026-03-17 06:40:00', NULL),
(201, 78, 'pending', 'assigned', NULL, 1, '2026-03-17 05:24:57', NULL),
(202, 78, 'assigned', 'in_progress', NULL, 16, '2026-03-17 08:12:00', NULL),
(203, 78, 'in_progress', 'completed', NULL, 16, '2026-03-17 09:42:00', NULL),
(204, 79, 'pending', 'assigned', NULL, 25, '2026-03-18 05:22:08', NULL),
(205, 80, 'pending', 'assigned', NULL, 1, '2026-03-18 05:04:30', NULL),
(206, 81, 'pending', 'assigned', NULL, 1, '2026-03-18 05:59:20', NULL),
(207, 82, 'pending', 'assigned', NULL, 6, '2026-03-18 05:25:42', NULL),
(208, 83, 'pending', 'assigned', NULL, 6, '2026-03-18 05:27:43', NULL),
(209, 84, 'pending', 'assigned', NULL, 25, '2026-03-18 05:22:14', NULL),
(210, 85, 'pending', 'assigned', NULL, 1, '2026-03-18 05:06:26', NULL),
(211, 86, 'pending', 'assigned', NULL, 1, '2026-03-18 05:49:07', NULL),
(212, 87, 'pending', 'assigned', NULL, 25, '2026-03-19 05:31:44', NULL),
(213, 88, 'pending', 'assigned', NULL, 1, '2026-03-19 05:23:34', NULL),
(214, 89, 'pending', 'assigned', NULL, 25, '2026-03-19 05:50:55', NULL),
(215, 90, 'pending', 'assigned', NULL, 25, '2026-03-19 05:05:03', NULL),
(216, 91, 'pending', 'assigned', NULL, 25, '2026-03-19 05:47:16', NULL),
(217, 92, 'pending', 'assigned', NULL, 6, '2026-03-19 05:27:14', NULL),
(218, 93, 'pending', 'assigned', NULL, 25, '2026-03-20 05:03:53', NULL),
(219, 94, 'pending', 'assigned', NULL, 25, '2026-03-20 05:29:20', NULL),
(220, 95, 'pending', 'assigned', NULL, 25, '2026-03-20 05:09:36', NULL),
(221, 96, 'pending', 'assigned', NULL, 6, '2026-03-20 05:06:26', NULL),
(222, 97, 'pending', 'assigned', NULL, 1, '2026-03-20 05:09:07', NULL),
(223, 98, 'pending', 'assigned', NULL, 25, '2026-03-20 05:50:11', NULL),
(224, 99, 'pending', 'assigned', NULL, 1, '2026-03-23 05:39:38', NULL),
(225, 100, 'pending', 'assigned', NULL, 6, '2026-03-23 05:28:26', NULL),
(226, 101, 'pending', 'assigned', NULL, 1, '2026-03-23 05:22:08', NULL),
(227, 102, 'pending', 'assigned', NULL, 1, '2026-03-23 05:39:33', NULL),
(228, 103, 'pending', 'assigned', NULL, 25, '2026-03-23 05:56:49', NULL),
(229, 104, 'pending', 'assigned', NULL, 25, '2026-03-23 05:46:09', NULL),
(230, 105, 'pending', 'assigned', NULL, 1, '2026-03-23 05:38:16', NULL),
(231, 106, 'pending', 'assigned', NULL, 6, '2026-03-23 05:40:03', NULL),
(232, 107, 'pending', 'assigned', NULL, 6, '2026-03-24 05:33:53', NULL),
(233, 108, 'pending', 'assigned', NULL, 1, '2026-03-24 05:56:32', NULL),
(234, 109, 'pending', 'assigned', NULL, 1, '2026-03-24 05:07:12', NULL),
(235, 110, 'pending', 'assigned', NULL, 25, '2026-03-24 05:25:16', NULL),
(236, 111, 'pending', 'assigned', NULL, 6, '2026-03-24 05:19:54', NULL),
(237, 112, 'pending', 'assigned', NULL, 25, '2026-03-24 05:02:07', NULL),
(238, 113, 'pending', 'assigned', NULL, 1, '2026-03-24 05:56:01', NULL),
(239, 114, 'pending', 'assigned', NULL, 25, '2026-03-25 05:05:18', NULL),
(240, 115, 'pending', 'assigned', NULL, 25, '2026-03-25 05:23:15', NULL),
(241, 116, 'pending', 'assigned', NULL, 6, '2026-03-25 05:55:51', NULL),
(242, 117, 'pending', 'assigned', NULL, 25, '2026-03-25 05:05:01', NULL),
(243, 118, 'pending', 'assigned', NULL, 1, '2026-03-25 05:13:06', NULL),
(244, 119, 'pending', 'assigned', NULL, 1, '2026-03-25 05:55:11', NULL),
(245, 120, 'pending', 'assigned', NULL, 6, '2026-03-26 05:36:16', NULL),
(246, 121, 'pending', 'assigned', NULL, 6, '2026-03-26 05:59:02', NULL),
(247, 122, 'pending', 'assigned', NULL, 25, '2026-03-26 05:27:40', NULL),
(248, 123, 'pending', 'assigned', NULL, 6, '2026-03-26 05:33:54', NULL),
(249, 124, 'pending', 'assigned', NULL, 25, '2026-03-27 05:55:55', NULL),
(250, 125, 'pending', 'assigned', NULL, 6, '2026-03-27 05:49:39', NULL),
(251, 126, 'pending', 'assigned', NULL, 25, '2026-03-27 05:36:26', NULL),
(252, 127, 'pending', 'assigned', NULL, 1, '2026-03-27 05:51:39', NULL),
(253, 128, 'pending', 'assigned', NULL, 6, '2026-03-27 05:05:39', NULL),
(254, 129, 'pending', 'assigned', NULL, 1, '2026-03-27 05:20:39', NULL),
(255, 130, 'pending', 'assigned', NULL, 25, '2026-03-30 05:58:16', NULL),
(256, 131, 'pending', 'assigned', NULL, 25, '2026-03-30 05:22:48', NULL),
(257, 132, 'pending', 'assigned', NULL, 25, '2026-03-30 05:11:07', NULL),
(258, 133, 'pending', 'assigned', NULL, 25, '2026-03-30 05:02:59', NULL),
(259, 134, 'pending', 'assigned', NULL, 6, '2026-03-30 05:30:59', NULL),
(260, 135, 'pending', 'assigned', NULL, 25, '2026-03-30 05:18:55', NULL),
(261, 136, 'pending', 'assigned', NULL, 25, '2026-03-30 05:37:20', NULL),
(262, 137, 'pending', 'assigned', NULL, 25, '2026-03-30 05:03:42', NULL),
(263, 138, 'pending', 'assigned', NULL, 25, '2026-03-30 05:41:05', NULL),
(264, 139, 'pending', 'assigned', NULL, 25, '2026-03-31 05:57:41', NULL),
(265, 140, 'pending', 'assigned', NULL, 1, '2026-03-31 05:40:27', NULL),
(266, 141, 'pending', 'assigned', NULL, 25, '2026-03-31 05:28:16', NULL),
(267, 142, 'pending', 'assigned', NULL, 25, '2026-03-31 05:29:43', NULL),
(268, 143, 'pending', 'assigned', NULL, 25, '2026-03-31 05:41:14', NULL),
(269, 144, 'pending', 'assigned', NULL, 1, '2026-03-31 05:55:03', NULL),
(270, 145, 'pending', 'assigned', NULL, 6, '2026-03-31 05:26:36', NULL),
(271, 146, 'pending', 'assigned', NULL, 25, '2026-03-31 05:17:47', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `job_technicians`
--

CREATE TABLE `job_technicians` (
  `id` int(10) UNSIGNED NOT NULL,
  `job_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `assigned_at` datetime NOT NULL DEFAULT current_timestamp(),
  `assigned_by` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `job_technicians`
--

INSERT INTO `job_technicians` (`id`, `job_id`, `user_id`, `assigned_at`, `assigned_by`) VALUES
(1, 1, 8, '2026-03-03 07:34:30', 6),
(2, 2, 12, '2026-03-03 07:03:53', 25),
(3, 2, 24, '2026-03-03 07:03:53', 25),
(4, 3, 19, '2026-03-03 07:05:01', 25),
(5, 3, 12, '2026-03-03 07:05:01', 25),
(6, 4, 21, '2026-03-03 07:01:03', 1),
(7, 5, 7, '2026-03-03 07:05:42', 1),
(8, 6, 20, '2026-03-03 07:12:56', 6),
(9, 7, 9, '2026-03-03 07:03:13', 25),
(10, 8, 20, '2026-03-04 07:39:37', 25),
(11, 9, 15, '2026-03-04 07:40:58', 6),
(12, 9, 17, '2026-03-04 07:40:58', 6),
(13, 10, 7, '2026-03-04 07:41:19', 25),
(14, 10, 19, '2026-03-04 07:41:19', 25),
(15, 11, 7, '2026-03-04 07:00:58', 1),
(16, 12, 10, '2026-03-04 07:32:55', 6),
(17, 13, 21, '2026-03-04 07:37:06', 6),
(18, 14, 20, '2026-03-04 07:31:14', 25),
(19, 15, 12, '2026-03-04 07:28:14', 6),
(20, 16, 10, '2026-03-05 07:25:06', 25),
(21, 17, 17, '2026-03-05 07:12:13', 1),
(22, 17, 22, '2026-03-05 07:12:13', 1),
(23, 18, 23, '2026-03-05 07:47:57', 1),
(24, 19, 16, '2026-03-05 07:27:20', 6),
(25, 20, 24, '2026-03-05 07:02:27', 6),
(26, 20, 15, '2026-03-05 07:02:27', 6),
(27, 21, 16, '2026-03-05 07:55:36', 25),
(28, 22, 15, '2026-03-06 07:11:02', 6),
(29, 23, 24, '2026-03-06 07:58:31', 25),
(30, 24, 11, '2026-03-06 07:16:16', 1),
(31, 25, 17, '2026-03-06 07:19:43', 1),
(32, 26, 20, '2026-03-06 07:43:13', 25),
(33, 27, 21, '2026-03-06 07:04:58', 6),
(34, 28, 14, '2026-03-06 07:27:24', 1),
(35, 29, 8, '2026-03-09 07:45:54', 1),
(36, 30, 17, '2026-03-09 07:22:15', 25),
(37, 31, 21, '2026-03-09 07:46:22', 6),
(38, 32, 23, '2026-03-09 07:03:59', 1),
(39, 33, 14, '2026-03-09 07:43:31', 6),
(40, 34, 20, '2026-03-09 07:42:19', 1),
(41, 35, 10, '2026-03-09 07:03:16', 25),
(42, 36, 15, '2026-03-09 07:29:48', 1),
(43, 37, 13, '2026-03-09 07:39:08', 25),
(44, 38, 8, '2026-03-10 07:29:26', 25),
(45, 39, 17, '2026-03-10 07:39:08', 6),
(46, 39, 14, '2026-03-10 07:39:08', 6),
(47, 40, 10, '2026-03-10 07:07:07', 25),
(48, 41, 7, '2026-03-10 07:44:58', 6),
(49, 42, 12, '2026-03-10 07:30:26', 6),
(50, 43, 8, '2026-03-10 07:20:31', 1),
(51, 44, 20, '2026-03-10 07:43:43', 6),
(52, 45, 22, '2026-03-10 07:20:00', 1),
(53, 46, 15, '2026-03-11 07:52:48', 25),
(54, 47, 10, '2026-03-11 07:03:26', 1),
(55, 48, 7, '2026-03-11 07:24:07', 25),
(56, 49, 22, '2026-03-11 07:28:38', 25),
(57, 49, 16, '2026-03-11 07:28:38', 25),
(58, 50, 18, '2026-03-11 07:54:51', 25),
(59, 51, 17, '2026-03-11 07:37:32', 25),
(60, 52, 15, '2026-03-12 07:17:38', 1),
(61, 53, 12, '2026-03-12 07:03:10', 1),
(62, 54, 17, '2026-03-12 07:31:38', 1),
(63, 55, 21, '2026-03-12 07:47:33', 25),
(64, 56, 7, '2026-03-13 07:41:31', 25),
(65, 56, 19, '2026-03-13 07:41:31', 25),
(66, 57, 7, '2026-03-13 07:20:33', 1),
(67, 58, 21, '2026-03-13 07:23:03', 1),
(68, 59, 20, '2026-03-13 07:00:55', 25),
(69, 60, 13, '2026-03-13 07:35:31', 25),
(70, 61, 22, '2026-03-13 07:47:06', 6),
(71, 61, 23, '2026-03-13 07:47:06', 6),
(72, 62, 14, '2026-03-13 07:52:41', 1),
(73, 62, 16, '2026-03-13 07:52:41', 1),
(74, 63, 12, '2026-03-16 07:37:18', 6),
(75, 63, 11, '2026-03-16 07:37:18', 6),
(76, 64, 13, '2026-03-16 07:35:50', 1),
(77, 65, 17, '2026-03-16 07:59:00', 1),
(78, 66, 21, '2026-03-16 07:46:02', 6),
(79, 67, 8, '2026-03-16 07:46:59', 6),
(80, 67, 10, '2026-03-16 07:46:59', 6),
(81, 68, 15, '2026-03-16 07:35:46', 6),
(82, 69, 16, '2026-03-16 07:38:40', 6),
(83, 70, 17, '2026-03-16 07:44:46', 25),
(84, 71, 15, '2026-03-17 07:37:37', 1),
(85, 71, 10, '2026-03-17 07:37:37', 1),
(86, 72, 7, '2026-03-17 07:14:04', 1),
(87, 72, 22, '2026-03-17 07:14:04', 1),
(88, 73, 13, '2026-03-17 07:14:06', 25),
(89, 74, 18, '2026-03-17 07:52:54', 6),
(90, 75, 24, '2026-03-17 07:54:00', 25),
(91, 76, 24, '2026-03-17 07:39:02', 1),
(92, 76, 23, '2026-03-17 07:39:02', 1),
(93, 77, 22, '2026-03-17 07:46:56', 1),
(94, 78, 16, '2026-03-17 07:24:57', 1),
(95, 79, 14, '2026-03-18 07:22:08', 25),
(96, 80, 7, '2026-03-18 07:04:30', 1),
(97, 80, 21, '2026-03-18 07:04:30', 1),
(98, 81, 23, '2026-03-18 07:59:20', 1),
(99, 81, 17, '2026-03-18 07:59:20', 1),
(100, 82, 15, '2026-03-18 07:25:42', 6),
(101, 83, 15, '2026-03-18 07:27:43', 6),
(102, 84, 24, '2026-03-18 07:22:14', 25),
(103, 85, 11, '2026-03-18 07:06:26', 1),
(104, 86, 22, '2026-03-18 07:49:07', 1),
(105, 87, 17, '2026-03-19 07:31:44', 25),
(106, 88, 8, '2026-03-19 07:23:34', 1),
(107, 89, 24, '2026-03-19 07:50:55', 25),
(108, 89, 21, '2026-03-19 07:50:55', 25),
(109, 90, 19, '2026-03-19 07:05:03', 25),
(110, 91, 12, '2026-03-19 07:47:16', 25),
(111, 92, 23, '2026-03-19 07:27:14', 6),
(112, 93, 10, '2026-03-20 07:03:53', 25),
(113, 94, 23, '2026-03-20 07:29:20', 25),
(114, 94, 22, '2026-03-20 07:29:20', 25),
(115, 95, 9, '2026-03-20 07:09:36', 25),
(116, 96, 23, '2026-03-20 07:06:26', 6),
(117, 97, 7, '2026-03-20 07:09:07', 1),
(118, 98, 11, '2026-03-20 07:50:11', 25),
(119, 99, 21, '2026-03-23 07:39:38', 1),
(120, 99, 7, '2026-03-23 07:39:38', 1),
(121, 100, 20, '2026-03-23 07:28:26', 6),
(122, 101, 22, '2026-03-23 07:22:08', 1),
(123, 102, 15, '2026-03-23 07:39:33', 1),
(124, 103, 11, '2026-03-23 07:56:49', 25),
(125, 104, 24, '2026-03-23 07:46:09', 25),
(126, 105, 18, '2026-03-23 07:38:16', 1),
(127, 106, 17, '2026-03-23 07:40:03', 6),
(128, 107, 16, '2026-03-24 07:33:53', 6),
(129, 108, 21, '2026-03-24 07:56:32', 1),
(130, 109, 24, '2026-03-24 07:07:12', 1),
(131, 110, 22, '2026-03-24 07:25:16', 25),
(132, 111, 19, '2026-03-24 07:19:54', 6),
(133, 112, 18, '2026-03-24 07:02:07', 25),
(134, 113, 19, '2026-03-24 07:56:01', 1),
(135, 114, 10, '2026-03-25 07:05:18', 25),
(136, 114, 19, '2026-03-25 07:05:18', 25),
(137, 115, 22, '2026-03-25 07:23:15', 25),
(138, 116, 11, '2026-03-25 07:55:51', 6),
(139, 117, 22, '2026-03-25 07:05:01', 25),
(140, 118, 18, '2026-03-25 07:13:06', 1),
(141, 119, 19, '2026-03-25 07:55:11', 1),
(142, 120, 22, '2026-03-26 07:36:16', 6),
(143, 121, 15, '2026-03-26 07:59:02', 6),
(144, 122, 8, '2026-03-26 07:27:40', 25),
(145, 123, 14, '2026-03-26 07:33:54', 6),
(146, 123, 17, '2026-03-26 07:33:54', 6),
(147, 124, 12, '2026-03-27 07:55:55', 25),
(148, 124, 14, '2026-03-27 07:55:55', 25),
(149, 125, 21, '2026-03-27 07:49:39', 6),
(150, 126, 24, '2026-03-27 07:36:26', 25),
(151, 127, 19, '2026-03-27 07:51:39', 1),
(152, 128, 20, '2026-03-27 07:05:39', 6),
(153, 129, 20, '2026-03-27 07:20:39', 1),
(154, 130, 17, '2026-03-30 07:58:16', 25),
(155, 130, 10, '2026-03-30 07:58:16', 25),
(156, 131, 11, '2026-03-30 07:22:48', 25),
(157, 131, 18, '2026-03-30 07:22:48', 25),
(158, 132, 16, '2026-03-30 07:11:07', 25),
(160, 134, 23, '2026-03-30 07:30:59', 6),
(161, 135, 24, '2026-03-30 07:18:55', 25),
(162, 136, 22, '2026-03-30 07:37:20', 25),
(163, 137, 24, '2026-03-30 07:03:42', 25),
(164, 138, 18, '2026-03-30 07:41:05', 25),
(165, 139, 11, '2026-03-31 07:57:41', 25),
(166, 140, 15, '2026-03-31 07:40:27', 1),
(167, 141, 17, '2026-03-31 07:28:16', 25),
(168, 141, 7, '2026-03-31 07:28:16', 25),
(169, 142, 21, '2026-03-31 07:29:43', 25),
(170, 143, 11, '2026-03-31 07:41:14', 25),
(171, 144, 20, '2026-03-31 07:55:03', 1),
(172, 145, 23, '2026-03-31 07:26:36', 6),
(173, 146, 20, '2026-03-31 07:17:47', 25);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(10) UNSIGNED NOT NULL,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `role` enum('admin','dispatcher','driver') NOT NULL DEFAULT 'driver',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `email`, `password_hash`, `full_name`, `role`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'admin', 'admin@company.com', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'System Admin', 'admin', 1, '2026-02-10 07:16:11', '2026-02-27 10:52:24'),
(6, 'olwethu', 'olwethu@realnet.co.sz', '$2b$10$GtQKmMKdmUsWk7zzO8jyNuxTSwPDxYWl3tytuRpqlPVrDkWCtp8W6', 'olwethu', 'admin', 1, '2026-03-03 07:47:37', '2026-03-03 07:47:37'),
(7, 'george.manyatsi', 'george.manyatsi@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'George Sky Manyatsi', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(8, 'sisimo.seyama', 'sisimo.seyama@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Sisimo Seyama', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(9, 'nick.mdluli', 'nick.mdluli@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Nick Mdluli', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(10, 'sphila.simelane', 'sphila.simelane@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Sphila Simelane', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(11, 'thembinkosi.dlamini', 'thembinkosi.dlamini@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Thembinkosi Coach Dlamini', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(12, 'monde.radebe', 'monde.radebe@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Monde Radebe', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(13, 'banele.tshabalala', 'banele.tshabalala@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Banele Tshabalala', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(14, 'sihle.masilela', 'sihle.masilela@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Sihle Masilela', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(15, 'sandile.masuku', 'sandile.masuku@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Sandile Masuku', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(16, 'ndumiso.mavimbela', 'ndumiso.mavimbela@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Ndumiso Mavimbela', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(17, 'sandile.d.dlamini', 'sandile.d.dlamini@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Sandile Darien Dlamini', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(18, 'goodluck.siyaya', 'goodluck.siyaya@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Goodluck Siyaya', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(19, 'mduduzi.gumedze', 'mduduzi.gumedze@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Mduduzi Gumedze', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(20, 'lwazi.kunene', 'lwazi.kunene@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Lwazi Kunene', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(21, 'mzwakhe.mavuso', 'mzwakhe.mavuso@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Mzwakhe Max Mavuso', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(22, 'lindani.masilela', 'lindani.masilela@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Lindani Masilela', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(23, 'edem.agkebe', 'edem.agkebe@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Edem Agkebe', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(24, 'warren.dlamini', 'warren.dlamini@realnet.co.sz', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Warren Sandile Dlamini', 'driver', 1, '2026-03-01 06:00:00', '2026-03-01 06:00:00'),
(25, 'tania', 'taina@gmail.com', '$2b$10$vE9jG4ZNhXLSUFfT2YQ0q.TTJ/rHw4/raaGmOp.PCvdlAsm4p8rmS', 'Tania M', 'dispatcher', 1, '2026-03-13 10:38:23', '2026-03-13 10:38:23');

-- --------------------------------------------------------

--
-- Table structure for table `vehicles`
--

CREATE TABLE `vehicles` (
  `id` int(10) UNSIGNED NOT NULL,
  `vehicle_name` varchar(100) NOT NULL,
  `license_plate` varchar(20) NOT NULL,
  `vehicle_type` enum('van','truck','car') NOT NULL,
  `capacity_kg` decimal(10,2) DEFAULT NULL COMMENT 'Weight capacity in kilograms',
  `is_active` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1=available, 0=out of service',
  `last_maintenance_date` date DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `vehicles`
--

INSERT INTO `vehicles` (`id`, `vehicle_name`, `license_plate`, `vehicle_type`, `capacity_kg`, `is_active`, `last_maintenance_date`, `notes`, `created_at`, `updated_at`) VALUES
(1, 'Vehicle 1 - Open NP200', 'SSD 123 BH', 'van', 500.00, 1, NULL, 'Deliveries, Pickups , Fixes', '2026-02-10 07:16:11', '2026-02-19 13:22:25'),
(2, 'Vehicle 2 - Closed NP200', 'BSD 789 BH', 'van', 500.00, 1, NULL, 'NP 200 with cover', '2026-02-10 07:16:11', '2026-02-19 13:24:52'),
(3, 'Vehicle 3 - NP 300', 'ESD 122 BH', 'van', 500.00, 1, NULL, 'Double cab for more people', '2026-02-10 07:16:11', '2026-02-19 13:24:26');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `jobs`
--
ALTER TABLE `jobs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `job_number` (`job_number`),
  ADD KEY `idx_scheduled_date` (`scheduled_date`),
  ADD KEY `idx_status` (`current_status`),
  ADD KEY `idx_type` (`job_type`),
  ADD KEY `idx_priority` (`priority`),
  ADD KEY `idx_date_status` (`scheduled_date`,`current_status`),
  ADD KEY `created_by` (`created_by`),
  ADD KEY `idx_jobs_schedule_active` (`scheduled_date`,`scheduled_time_start`,`scheduled_time_end`,`current_status`),
  ADD KEY `idx_jobs_status` (`current_status`,`id`),
  ADD KEY `idx_jobs_schedule` (`scheduled_date`,`scheduled_time_start`,`scheduled_time_end`,`current_status`);

--
-- Indexes for table `job_assignments`
--
ALTER TABLE `job_assignments`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_vehicle_job` (`vehicle_id`,`job_id`),
  ADD UNIQUE KEY `unique_job_vehicle` (`job_id`,`vehicle_id`),
  ADD KEY `assigned_by` (`assigned_by`),
  ADD KEY `idx_job` (`job_id`),
  ADD KEY `idx_vehicle` (`vehicle_id`),
  ADD KEY `idx_driver` (`driver_id`),
  ADD KEY `idx_assigned_at` (`assigned_at`),
  ADD KEY `idx_assignments_job` (`job_id`),
  ADD KEY `idx_assignments_vehicle` (`vehicle_id`,`job_id`);

--
-- Indexes for table `job_status_changes`
--
ALTER TABLE `job_status_changes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_job_id` (`job_id`),
  ADD KEY `idx_changed_at` (`changed_at`),
  ADD KEY `changed_by` (`changed_by`);

--
-- Indexes for table `job_technicians`
--
ALTER TABLE `job_technicians`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_job_tech` (`job_id`,`user_id`),
  ADD KEY `fk_jt_user` (`user_id`),
  ADD KEY `fk_jt_by` (`assigned_by`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_role` (`role`),
  ADD KEY `idx_active` (`is_active`);

--
-- Indexes for table `vehicles`
--
ALTER TABLE `vehicles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `license_plate` (`license_plate`),
  ADD KEY `idx_active` (`is_active`),
  ADD KEY `idx_type` (`vehicle_type`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `jobs`
--
ALTER TABLE `jobs`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `job_assignments`
--
ALTER TABLE `job_assignments`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=148;

--
-- AUTO_INCREMENT for table `job_status_changes`
--
ALTER TABLE `job_status_changes`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=272;

--
-- AUTO_INCREMENT for table `job_technicians`
--
ALTER TABLE `job_technicians`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=174;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `vehicles`
--
ALTER TABLE `vehicles`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `jobs`
--
ALTER TABLE `jobs`
  ADD CONSTRAINT `jobs_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `job_assignments`
--
ALTER TABLE `job_assignments`
  ADD CONSTRAINT `job_assignments_ibfk_1` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `job_assignments_ibfk_2` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `job_assignments_ibfk_3` FOREIGN KEY (`driver_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `job_assignments_ibfk_4` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `job_status_changes`
--
ALTER TABLE `job_status_changes`
  ADD CONSTRAINT `job_status_changes_ibfk_1` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `job_status_changes_ibfk_2` FOREIGN KEY (`changed_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `job_technicians`
--
ALTER TABLE `job_technicians`
  ADD CONSTRAINT `fk_jt_by` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `fk_jt_job` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_jt_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
