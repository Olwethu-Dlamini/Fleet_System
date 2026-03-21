-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 13, 2026 at 11:57 AM
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
  `destination_lat` double DEFAULT NULL,
  `destination_lng` double DEFAULT NULL,
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
(1, 'JOB-2026-0001', 'installation', 'tesst', '1212121', 'cvgdsgfds', 'lllolo', '2026-03-11', '09:00:00', '12:00:00', 180, 'cancelled', 'normal', 6, '2026-03-11 08:41:50', '2026-03-11 10:34:36'),
(2, 'JOB-2026-0002', 'miscellaneous', 'all job', 'gg', 'dgdgtdg', 'Miscellous test', '2026-03-11', '09:00:00', '12:00:00', 180, 'cancelled', 'normal', 6, '2026-03-11 08:46:21', '2026-03-11 10:35:01'),
(3, 'JOB-2026-0003', 'miscellaneous', 'tes3', 'dddtrer', 'teet', 'rtrtstsr', '2026-03-11', '12:00:00', '13:00:00', 60, 'cancelled', 'normal', 6, '2026-03-11 08:48:28', '2026-03-11 09:36:56'),
(4, 'JOB-2026-0004', 'miscellaneous', 'test 3', 'gsgsdg', 'gdgsdg', 'gdgdgs', '2026-03-11', '14:00:00', '15:00:00', 60, 'completed', 'normal', 6, '2026-03-11 08:49:39', '2026-03-11 08:56:45'),
(5, 'JOB-2026-0005', 'miscellaneous', 'test of vehicle with', 'gdsgdsgs', 'efdfdfdf', 'gdsgdsgds', '2026-03-11', '14:00:00', '16:12:00', 132, 'cancelled', 'urgent', 6, '2026-03-11 09:18:02', '2026-03-11 09:36:21'),
(6, 'JOB-2026-0006', 'miscellaneous', 'tessw', '12121', 'sdsd', 'sdsdsvcvcvc', '2026-03-11', '09:00:00', '13:00:00', 240, 'cancelled', 'high', 6, '2026-03-11 10:02:22', '2026-03-11 10:10:20'),
(7, 'JOB-2026-0007', 'miscellaneous', 'tessw', '12121', 'sdsd', 'sdsdsvcvcvc', '2026-03-11', '09:00:00', '13:00:00', 240, 'cancelled', 'high', 6, '2026-03-11 10:02:34', '2026-03-11 10:03:36'),
(8, 'JOB-2026-0008', 'miscellaneous', 'test red screen', '23221', 'mnbaddgf', 'vfsvsavv', '2026-03-11', '09:00:00', '12:00:00', 180, 'completed', 'low', 6, '2026-03-11 10:15:29', '2026-03-11 10:40:58'),
(9, 'JOB-2026-0009', 'miscellaneous', 'terterhg5', 'fdsgg', 'gdsgdsg', 'gdgds', '2026-03-12', '09:00:00', '12:00:00', 180, 'cancelled', 'normal', 6, '2026-03-11 10:15:56', '2026-03-11 10:16:25'),
(10, 'JOB-2026-0010', 'miscellaneous', 'feet', 'trtt', '42321', 'hfdhhfgf', '2026-03-11', '15:00:00', '16:00:00', 60, 'assigned', 'low', 6, '2026-03-11 10:52:33', '2026-03-11 10:53:11'),
(11, 'JOB-2026-0011', 'delivery', 'driver kick', 'dgds', 'gsdgfdsg', 'gsgdsg', '2026-03-11', '15:00:00', '15:04:00', 4, 'completed', 'normal', 6, '2026-03-11 10:56:26', '2026-03-11 11:42:26'),
(12, 'JOB-2026-0012', 'delivery', 'vvvvv', '12345', 'gfsgsfdg', 'ggsg', '2026-03-11', '09:00:00', '12:00:00', 180, 'assigned', 'normal', 6, '2026-03-11 11:24:58', '2026-03-11 11:26:21'),
(13, 'JOB-2026-0013', 'installation', 'driver swap', 'fdfdafdsa', 'dafdafda', 'dafdfda', '2026-03-11', '09:00:00', '12:00:00', 180, 'assigned', 'urgent', 6, '2026-03-11 11:45:32', '2026-03-11 11:46:01'),
(14, 'JOB-2026-0014', 'miscellaneous', 'tannniiiiiaaaaa', 'nnnn', 'nnnnn', 'nnggngngn', '2026-03-13', '08:00:00', '11:00:00', 180, 'assigned', 'high', 25, '2026-03-13 10:41:08', '2026-03-13 10:41:40');

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
(1, 1, 6, NULL, '2026-03-11 08:41:50', 6, NULL),
(2, 2, 1, NULL, '2026-03-11 08:46:39', 6, NULL),
(3, 4, 2, NULL, '2026-03-11 08:49:40', 6, NULL),
(4, 7, 3, NULL, '2026-03-11 10:02:34', 6, NULL),
(5, 8, 2, NULL, '2026-03-11 10:15:30', 6, NULL),
(6, 10, 6, NULL, '2026-03-11 10:53:11', 6, NULL),
(9, 11, 2, NULL, '2026-03-11 11:23:22', 6, NULL),
(10, 12, 2, NULL, '2026-03-11 11:26:21', 6, NULL),
(11, 13, 1, NULL, '2026-03-11 11:46:01', 6, NULL),
(12, 14, 3, NULL, '2026-03-13 10:41:08', 25, NULL);

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
(1, 4, 'assigned', 'in_progress', NULL, 14, '2026-03-11 08:55:17', NULL),
(2, 4, 'in_progress', 'completed', NULL, 14, '2026-03-11 08:56:45', NULL),
(3, 5, 'pending', 'cancelled', 'no car', 6, '2026-03-11 09:33:41', NULL),
(4, 3, 'pending', 'cancelled', 'police arrest', 6, '2026-03-11 09:36:56', NULL),
(5, 7, 'assigned', 'cancelled', 'no fuel on car', 6, '2026-03-11 10:03:36', NULL),
(6, 6, 'pending', 'cancelled', 'no customer ran away', 6, '2026-03-11 10:10:20', NULL),
(7, 9, 'pending', 'cancelled', 'no remote control for gate', 6, '2026-03-11 10:16:25', NULL),
(8, 1, 'assigned', 'cancelled', 'no wifi and stolen property', 6, '2026-03-11 10:34:36', NULL),
(9, 2, 'assigned', 'cancelled', 'no gaseses', 6, '2026-03-11 10:35:01', NULL),
(10, 8, 'assigned', 'in_progress', NULL, 15, '2026-03-11 10:40:42', NULL),
(11, 8, 'in_progress', 'completed', NULL, 15, '2026-03-11 10:40:58', NULL),
(12, 11, 'assigned', 'in_progress', NULL, 6, '2026-03-11 11:42:09', NULL),
(13, 11, 'in_progress', 'completed', NULL, 15, '2026-03-11 11:42:26', NULL);

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
(56, 3, 13, '2026-03-11 10:48:28', 6),
(57, 3, 23, '2026-03-11 10:48:28', 6),
(58, 3, 7, '2026-03-11 10:48:28', 6),
(59, 3, 18, '2026-03-11 10:48:28', 6),
(60, 3, 22, '2026-03-11 10:48:28', 6),
(61, 3, 19, '2026-03-11 10:48:28', 6),
(62, 3, 12, '2026-03-11 10:48:28', 6),
(63, 3, 20, '2026-03-11 10:48:28', 6),
(64, 3, 10, '2026-03-11 10:48:28', 6),
(65, 3, 8, '2026-03-11 10:48:28', 6),
(66, 3, 14, '2026-03-11 10:48:28', 6),
(67, 3, 15, '2026-03-11 10:48:28', 6),
(68, 3, 17, '2026-03-11 10:48:28', 6),
(69, 3, 9, '2026-03-11 10:48:28', 6),
(70, 3, 16, '2026-03-11 10:48:28', 6),
(71, 3, 21, '2026-03-11 10:48:28', 6),
(72, 3, 11, '2026-03-11 10:48:28', 6),
(73, 3, 24, '2026-03-11 10:48:28', 6),
(76, 4, 13, '2026-03-11 10:52:51', 6),
(77, 4, 7, '2026-03-11 10:52:51', 6),
(78, 4, 23, '2026-03-11 10:52:51', 6),
(79, 4, 18, '2026-03-11 10:52:51', 6),
(80, 4, 22, '2026-03-11 10:52:51', 6),
(81, 4, 20, '2026-03-11 10:52:51', 6),
(82, 4, 19, '2026-03-11 10:52:51', 6),
(83, 4, 12, '2026-03-11 10:52:51', 6),
(84, 4, 21, '2026-03-11 10:52:51', 6),
(85, 4, 16, '2026-03-11 10:52:51', 6),
(86, 4, 9, '2026-03-11 10:52:51', 6),
(87, 4, 17, '2026-03-11 10:52:51', 6),
(88, 4, 15, '2026-03-11 10:52:51', 6),
(89, 4, 14, '2026-03-11 10:52:51', 6),
(90, 4, 8, '2026-03-11 10:52:51', 6),
(91, 4, 10, '2026-03-11 10:52:51', 6),
(92, 4, 11, '2026-03-11 10:52:51', 6),
(93, 4, 24, '2026-03-11 10:52:51', 6),
(94, 5, 13, '2026-03-11 11:18:02', 6),
(95, 5, 11, '2026-03-11 11:18:02', 6),
(96, 5, 21, '2026-03-11 11:18:02', 6),
(97, 1, 23, '2026-03-11 11:25:38', 6),
(98, 2, 7, '2026-03-11 11:25:56', 6),
(99, 2, 18, '2026-03-11 11:25:56', 6),
(100, 2, 13, '2026-03-11 11:25:56', 6),
(101, 7, 20, '2026-03-11 12:02:34', 6),
(102, 7, 19, '2026-03-11 12:02:34', 6),
(103, 8, 17, '2026-03-11 12:15:30', 6),
(104, 8, 15, '2026-03-11 12:15:30', 6),
(108, 11, 15, '2026-03-11 13:23:22', 6),
(111, 10, 15, '2026-03-11 13:43:26', 6),
(114, 13, 14, '2026-03-13 12:05:05', 6),
(115, 13, 15, '2026-03-13 12:05:05', 6),
(116, 14, 13, '2026-03-13 12:41:09', 25),
(117, 14, 9, '2026-03-13 12:41:09', 25),
(118, 14, 18, '2026-03-13 12:41:09', 25);

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
(3, 'Vehicle 3 - NP 300', 'ESD 122 BH', 'van', 500.00, 1, NULL, 'Double cab for more people', '2026-02-10 07:16:11', '2026-02-19 13:24:26'),
(6, 'test vehicle', '123444', 'van', 400.00, 0, NULL, NULL, '2026-03-11 07:15:48', '2026-03-13 10:16:24');

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
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `job_status_changes`
--
ALTER TABLE `job_status_changes`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `job_technicians`
--
ALTER TABLE `job_technicians`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=119;

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

-- ============================================
-- TIME MANAGEMENT TABLES (Phase 06 - TIME-01 to TIME-07)
-- ============================================

CREATE TABLE IF NOT EXISTS `time_extension_requests` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `tenant_id` int(10) UNSIGNED NOT NULL,
  `job_id` int(10) UNSIGNED NOT NULL,
  `requested_by` int(10) UNSIGNED NOT NULL,
  `duration_minutes` int(10) UNSIGNED NOT NULL,
  `reason` text NOT NULL,
  `status` enum('pending','approved','denied') NOT NULL DEFAULT 'pending',
  `denial_reason` text DEFAULT NULL,
  `approved_denied_by` int(10) UNSIGNED DEFAULT NULL,
  `approved_denied_at` timestamp NULL DEFAULT NULL,
  `selected_suggestion_id` int(10) UNSIGNED DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ter_job_status` (`job_id`,`status`),
  KEY `idx_ter_tenant` (`tenant_id`),
  KEY `idx_ter_requested_by` (`requested_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `reschedule_options` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_id` int(10) UNSIGNED NOT NULL,
  `tenant_id` int(10) UNSIGNED NOT NULL,
  `type` enum('push','swap','custom') NOT NULL,
  `label` varchar(100) NOT NULL,
  `changes_json` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ro_request` (`request_id`),
  KEY `idx_ro_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
