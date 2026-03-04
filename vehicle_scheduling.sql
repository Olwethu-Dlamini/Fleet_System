-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 04, 2026 at 06:21 PM
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
  `job_type` enum('installation','delivery','maintenance') NOT NULL,
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
(1, 'JOB-2026-0001', 'installation', 'olwethu', '12121212', 'Swazi TV road', 'Insatll new kit and ensure wifi is on and account is set', '2026-03-04', '08:00:00', '17:00:00', 540, 'in_progress', 'high', 2, '2026-03-04 14:08:59', '2026-03-04 14:09:26');

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
(1, 1, 2, NULL, '2026-03-04 14:09:00', 2, NULL);

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
(1, 1, 'assigned', 'in_progress', NULL, 2, '2026-03-04 14:09:26', NULL);

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
(2, 'dispatcher1', 'dispatcher@company.com', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'John Dispatcher', 'dispatcher', 1, '2026-02-10 07:16:11', '2026-02-27 10:52:02'),
(3, 'driver1', 'driver1@company.com', '$2b$10$qwFyxHz1kterDHRxpoN6AefYQL8yTdpBoDiITW4wTiTlt1QBjesxW', 'Mike Driver', 'driver', 1, '2026-02-10 07:16:11', '2026-02-27 10:52:34'),
(4, 'driver2', 'driver2@company.com', '$2b$10$W7m9J6dE9g7XyXz8k9x1Eehp8j2vYkqS9bJ8D3m6N5Y4Q2R1T0A1C', 'Sarah Driver', 'driver', 1, '2026-02-10 07:16:11', '2026-02-27 10:49:30'),
(5, 'driver3', 'driver3@company.com', '$2b$10$W7m9J6dE9g7XyXz8k9x1Eehp8j2vYkqS9bJ8D3m6N5Y4Q2R1T0A1C', 'Tom Driver', 'driver', 0, '2026-02-10 07:16:11', '2026-03-03 07:47:02'),
(6, 'olwethu', 'olwethu@realnet.co.sz', '$2b$10$GtQKmMKdmUsWk7zzO8jyNuxTSwPDxYWl3tytuRpqlPVrDkWCtp8W6', 'olwethu', 'admin', 1, '2026-03-03 07:47:37', '2026-03-03 07:47:37');

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
(4, 'Toyota Starlet', 'ASD 208 DH', 'car', 200.00, 0, NULL, NULL, '2026-03-03 08:07:46', '2026-03-04 13:01:03');

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
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `job_status_changes`
--
ALTER TABLE `job_status_changes`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `job_technicians`
--
ALTER TABLE `job_technicians`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `vehicles`
--
ALTER TABLE `vehicles`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

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
